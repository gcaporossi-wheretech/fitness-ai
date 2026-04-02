# Stage 1: Build
FROM python:3.12-slim AS builder

WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# Stage 2: Runtime
FROM python:3.12-slim

RUN groupadd -r appuser && useradd -r -g appuser appuser

WORKDIR /app
COPY --from=builder /install /usr/local
COPY . .

RUN chown -R appuser:appuser /app
USER appuser

EXPOSE 8001

HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD python -c "import httpx; httpx.get('http://localhost:8001/health')" || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8001"]
