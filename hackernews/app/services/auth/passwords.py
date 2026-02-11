import os
import hashlib
import hmac


def _pbkdf2_hash(password: str, salt: bytes, iterations: int = 120_000) -> bytes:
    return hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, iterations)


def hash_password(password: str) -> str:
    salt = os.urandom(16)
    iterations = 120_000
    dk = _pbkdf2_hash(password, salt, iterations)
    return f"pbkdf2_sha256${iterations}${salt.hex()}${dk.hex()}"


def verify_password(password: str, stored: str) -> bool:
    try:
        scheme, iter_str, salt_hex, hash_hex = stored.split("$", 3)
        if scheme != "pbkdf2_sha256":
            return False
        iterations = int(iter_str)
        salt = bytes.fromhex(salt_hex)
        expected = bytes.fromhex(hash_hex)
        actual = _pbkdf2_hash(password, salt, iterations)
        return hmac.compare_digest(actual, expected)
    except Exception:
        return False
