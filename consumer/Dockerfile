FROM python:3.9-slim-buster

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY consumer.py .

VOLUME /app/data  # Create a volume for the database file

CMD ["python", "consumer.py"]