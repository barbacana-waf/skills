Deployment notes: Barbacana sits behind an AWS ALB that terminates TLS.
The ALB appends the real client address to X-Forwarded-For.
