FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY exporter.py .

USER 1000:1000
EXPOSE 9666

CMD ["python", "-u", "exporter.py"]
