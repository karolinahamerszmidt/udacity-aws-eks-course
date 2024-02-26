FROM public.ecr.aws/sam/build-python3.8:latest

COPY . /app
WORKDIR /app

RUN pip install --upgrade pip
RUN pip install -r requirements.txt

ENTRYPOINT ["gunicorn", "-b", ":8080", "app:APP"]
