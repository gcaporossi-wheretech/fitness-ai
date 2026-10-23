#!/bin/bash
# FitnessAI — One-command deploy from the dev PC (Git Bash on Windows, or any
# bash with ssh, tar, curl, the AWS CLI and Flutter).
#
#   1. checks the local checkout matches origin/<branch> (what gets deployed)
#   2. starts the EC2 instance if it is stopped
#   3. opens SSH for this PC's public IP if needed (closed again on exit)
#   4. builds the Flutter PWA
#   5. runs infra/aws/deploy.sh on the server (code, DB backup, migrations,
#      containers)
#   6. uploads the PWA (previous version kept in ~/webapp.prev on the server)
#   7. smoke-tests the public site
#
# Usage: infra/aws/deploy-remote.sh [branch]   (default: develop)
#
# Overridable env: DEPLOY_HOST, DEPLOY_SSH_KEY, DEPLOY_URL, FLUTTER

set -euo pipefail

BRANCH="${1:-develop}"
REGION="eu-west-1"
INSTANCE_ID="i-02219bbf3b3e88587"
SECURITY_GROUP="sg-08f06001b903d760b"
HOST="${DEPLOY_HOST:-ubuntu@54.170.27.110}"
SSH_KEY="${DEPLOY_SSH_KEY:-${HOME}/.ssh/test-caporossi-key.pem}"
URL="${DEPLOY_URL:-https://fitness-ai.caporossi.net}"
SSH="ssh -i ${SSH_KEY} -o ConnectTimeout=20 -o StrictHostKeyChecking=accept-new ${HOST}"

ROOT=$(git rev-parse --show-toplevel)
cd "${ROOT}"

if [ -z "${FLUTTER:-}" ]; then
    if command -v flutter >/dev/null 2>&1; then FLUTTER=flutter
    else FLUTTER="${HOME}/flutter/bin/flutter"; fi
fi

echo "=== FitnessAI remote deploy (branch: ${BRANCH}) ==="

# 1. Deploy exactly what is on GitHub
echo "[1/7] Checking local checkout..."
git fetch -q origin
if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
    echo "ERROR: uncommitted changes. Commit and push before deploying."
    exit 1
fi
if [ "$(git rev-parse HEAD)" != "$(git rev-parse "origin/${BRANCH}")" ]; then
    echo "ERROR: HEAD is not origin/${BRANCH}. Run: git checkout ${BRANCH} && git pull"
    exit 1
fi
echo "  Commit: $(git log --oneline -1)"

# 2. Instance running?
echo "[2/7] Checking EC2 instance..."
STATE=$(aws ec2 describe-instances --region "${REGION}" --instance-ids "${INSTANCE_ID}" \
    --query "Reservations[0].Instances[0].State.Name" --output text)
if [ "${STATE}" != "running" ]; then
    echo "  Instance is ${STATE}: starting it..."
    aws ec2 start-instances --region "${REGION}" --instance-ids "${INSTANCE_ID}" >/dev/null
    aws ec2 wait instance-running --region "${REGION}" --instance-ids "${INSTANCE_ID}"
fi
echo "  Instance running"

# 3. SSH reachable from this IP? Otherwise open port 22 temporarily
echo "[3/7] Checking SSH access..."
MY_IP=$(curl -s -m 10 https://checkip.amazonaws.com | tr -d '[:space:]')
ALLOWED=$(aws ec2 describe-security-groups --region "${REGION}" --group-ids "${SECURITY_GROUP}" \
    --query "SecurityGroups[0].IpPermissions[?FromPort==\`22\`].IpRanges[].CidrIp" --output text)
TEMP_RULE=""
close_ssh() {
    if [ -n "${TEMP_RULE}" ]; then
        aws ec2 revoke-security-group-ingress --region "${REGION}" --group-id "${SECURITY_GROUP}" \
            --security-group-rule-ids "${TEMP_RULE}" >/dev/null && echo "  Temporary SSH rule removed"
    fi
}
trap close_ssh EXIT
if ! echo "${ALLOWED}" | grep -qw "${MY_IP}/32"; then
    TEMP_RULE=$(aws ec2 authorize-security-group-ingress --region "${REGION}" --group-id "${SECURITY_GROUP}" \
        --ip-permissions "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=${MY_IP}/32,Description=deploy-remote-temp}]" \
        --query "SecurityGroupRules[0].SecurityGroupRuleId" --output text)
    echo "  Opened SSH for ${MY_IP} (rule ${TEMP_RULE})"
fi
for _ in $(seq 1 30); do
    ${SSH} true 2>/dev/null && break
    sleep 5
done

# 4. Build the PWA
echo "[4/7] Building Flutter PWA..."
(cd app && "${FLUTTER}" pub get --suppress-analytics >/dev/null \
    && "${FLUTTER}" build web --release --suppress-analytics)

# 5. Backend: the server aligns itself to origin/<branch> and redeploys.
#    Fetch first so the freshly pulled deploy.sh is the one that runs.
echo "[5/7] Deploying backend on the server..."
${SSH} "cd /opt/fitnessai && git fetch -q origin && git checkout -q --force -B ${BRANCH} origin/${BRANCH} && ./infra/aws/deploy.sh ${BRANCH}"

# 6. PWA: upload to a staging dir, keep the previous build, then sync in
#    place (nginx bind-mounts the directory, so it must not be renamed)
echo "[6/7] Uploading PWA..."
${SSH} "rm -rf ~/webapp.new && mkdir ~/webapp.new"
tar -C app/build/web -cf - --exclude=.last_build_id . | ${SSH} "tar -xf - -C ~/webapp.new"
${SSH} "rm -rf ~/webapp.prev && cp -a /opt/fitnessai/webapp ~/webapp.prev \
    && rsync -a --delete ~/webapp.new/ /opt/fitnessai/webapp/ && rm -rf ~/webapp.new"

# 7. Smoke test
echo "[7/7] Smoke test..."
FAIL=0
check() {
    local path="$1" expected="$2" code
    code=$(curl -s -o /dev/null -m 20 -w "%{http_code}" "${URL}${path}")
    if [ "${code}" = "${expected}" ]; then echo "  OK   ${path} -> ${code}"
    else echo "  FAIL ${path} -> ${code} (expected ${expected})"; FAIL=1; fi
}
check "/" 200
check "/main.dart.js" 200
check "/auth/me" 401
check "/workouts/plans" 401

if [ "${FAIL}" = 0 ]; then
    echo "=== Deploy OK: ${URL} ($(git rev-parse --short HEAD)) ==="
else
    echo "=== Deploy completed with smoke test failures ==="
    exit 1
fi
