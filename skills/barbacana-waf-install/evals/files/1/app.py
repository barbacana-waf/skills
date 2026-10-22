from flask import Flask

app = Flask(__name__)


@app.get("/")
def index():
    return {"ok": True}


@app.get("/search")
def search():
    return {"results": []}
