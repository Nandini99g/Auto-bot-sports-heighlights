# app/logger.py
import logging
import io
import time

class PipelineLogger:
    def __init__(self):
        self.buf = io.StringIO()
        self.logger = logging.getLogger("pipeline")
        handler = logging.StreamHandler()
        handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)s: %(message)s"))
        self.logger.setLevel(logging.INFO)
        if not self.logger.handlers:
            self.logger.addHandler(handler)

    def info(self, msg):
        self.logger.info(msg)
        self.buf.write(f"{time.strftime('%Y-%m-%d %H:%M:%S')} INFO: {msg}\n")

    def error(self, msg):
        self.logger.error(msg)
        self.buf.write(f"{time.strftime('%Y-%m-%d %H:%M:%S')} ERROR: {msg}\n")

    def get_bytes(self):
        return self.buf.getvalue().encode("utf-8")
