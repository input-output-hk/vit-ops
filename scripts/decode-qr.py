#!/usr/bin/python3

import sys
from cryptography.hazmat.backends import openssl
from cryptography.hazmat.primitives.ciphers.aead import ChaCha20Poly1305
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import hashes

import cv2 as cv

im = cv.imread(sys.argv[1])

det = cv.QRCodeDetector()

retval, points, straight_qrcode = det.detectAndDecode(im)
data = bytes.fromhex(retval)
pin = sys.argv[2]

password = bytes([int(d) for d in pin])
salt = data[1:17]
nonce = data[17:29]
cipher = data[29:]

kdf = PBKDF2HMAC(
    algorithm=hashes.SHA512(),
    length=32,
    salt=salt,
    iterations=12983,
    backend=openssl.backend,
)
key = kdf.derive(password)
chacha = ChaCha20Poly1305(key)
plaintext = chacha.decrypt(nonce, cipher, None)

print(plaintext.hex())
