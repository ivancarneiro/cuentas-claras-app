# -*- coding: utf-8 -*-
"""
Tests de contrato para verificación de versión de la aplicación y descarga de APK.
"""

def test_check_latest_version_no_update(client):
    """Si la versión local es igual a la remota, update_required debe ser False."""
    res = client.get("/api/version/latest?current_version=1.0.5")
    assert res.status_code == 200
    data = res.get_json()
    assert "latest_version" in data
    assert "download_url" in data
    assert data["update_required"] is False


def test_check_latest_version_update_required(client):
    """Si la versión local es menor (1.0.4 < 1.0.5), update_required debe ser True."""
    res = client.get("/api/version/latest?current_version=1.0.4")
    assert res.status_code == 200
    data = res.get_json()
    assert data["update_required"] is True
    assert data["latest_version"] == "1.0.5"
    assert "/api/version/download" in data["download_url"]


def test_download_apk_endpoint_redirects(client):
    """El endpoint /api/version/download debe devolver un redirect 302 hacia el release o asset."""
    res = client.get("/api/version/download", follow_redirects=False)
    assert res.status_code == 302
    assert "Location" in res.headers
