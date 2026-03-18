FROM python:3.12-alpine

WORKDIR /app

ENV PYTHONUNBUFFERED=1
COPY proxy.py .
RUN chmod +x proxy.py

HEALTHCHECK --interval=5s --timeout=3s --start-period=2s --retries=3 \
  CMD python3 -c "import socket; socket.create_connection(('localhost', 8080), timeout=2)" || exit 1

ENTRYPOINT ["python3", "proxy.py"]
