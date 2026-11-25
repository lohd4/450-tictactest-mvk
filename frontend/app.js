/*
 * TicTacTest frontend.
 *
 * Two things are deliberately NOT hardcoded here:
 *
 *   consoleUrl / versionUrl  come from config.js, which the infrastructure
 *                            (Terraform) writes per environment. Locally it
 *                            points at localhost, in the cloud at the EC2
 *                            instance. A frontend deployment never touches it.
 *
 *   the frontend version     comes from version.json, which the release
 *                            workflow writes into the frontend archive. It is
 *                            therefore always the released version, never a
 *                            number someone kept up to date by hand.
 */
(function () {
	'use strict';

	var config = window.TICTACTEST_CONFIG || {};
	var terminal = document.getElementById('terminal');
	var errorBox = document.getElementById('console-error');
	var restartButton = document.getElementById('restart');

	function showError(message) {
		errorBox.textContent = message;
		errorBox.hidden = false;
	}

	function setVersion(elementId, value) {
		document.getElementById(elementId).textContent = value;
	}

	// --- web console ---------------------------------------------------------

	if (!config.consoleUrl) {
		showError('Keine Konsolen-URL konfiguriert: config.js fehlt oder ist leer. ' +
				'Lokal: frontend/config.sample.js nach config.js kopieren. ' +
				'In der Cloud schreibt Terraform diese Datei.');
	} else {
		terminal.src = config.consoleUrl;
	}

	// Each connection to the web console starts its own JVM, and the process ends
	// when the game does. Reloading the iframe is therefore how a new game starts.
	restartButton.addEventListener('click', function () {
		if (!config.consoleUrl) {
			return;
		}
		// Re-assigning src (rather than reload()) also works cross-origin.
		terminal.src = 'about:blank';
		window.setTimeout(function () {
			terminal.src = config.consoleUrl;
			terminal.focus();
		}, 50);
	});

	// --- versions ------------------------------------------------------------

	// Frontend: same origin as this page, so a plain fetch is enough.
	fetch('version.json', { cache: 'no-store' })
			.then(function (response) {
				if (!response.ok) {
					throw new Error('HTTP ' + response.status);
				}
				return response.json();
			})
			.then(function (data) {
				setVersion('frontend-version', data.version || 'unbekannt');
			})
			.catch(function () {
				setVersion('frontend-version', 'unbekannt');
			});

	// Backend: a different origin (S3 website vs. EC2), so the version endpoint
	// must send Access-Control-Allow-Origin. nginx on the instance does that.
	if (config.versionUrl) {
		fetch(config.versionUrl, { cache: 'no-store' })
				.then(function (response) {
					if (!response.ok) {
						throw new Error('HTTP ' + response.status);
					}
					return response.text();
				})
				.then(function (text) {
					setVersion('backend-version', text.trim() || 'unbekannt');
				})
				.catch(function (error) {
					setVersion('backend-version', 'nicht erreichbar');
					console.warn('[TicTacTest] Backend-Version nicht abrufbar:', error.message);
				});
	} else {
		setVersion('backend-version', 'nicht konfiguriert');
	}
})();
