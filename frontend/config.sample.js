/*
 * Per-environment configuration for the TicTacTest frontend.
 *
 * This file is NOT part of the frontend release archive. The infrastructure
 * owns it: Terraform writes the real config.js into the S3 bucket, because only
 * the infrastructure knows the address of the EC2 instance. A frontend
 * deployment syncs with --exclude config.js so it survives (see
 * docs/webkonsole.md and docs/deployment.md).
 *
 * For local development: cp config.sample.js config.js
 */
window.TICTACTEST_CONFIG = {
	// Web console (ttyd, reverse-proxied by nginx). Embedded as an <iframe>.
	consoleUrl: 'http://localhost:8080/',
	// Plain-text endpoint returning the running backend version, e.g. "1.1.0".
	versionUrl: 'http://localhost:8080/version'
};
