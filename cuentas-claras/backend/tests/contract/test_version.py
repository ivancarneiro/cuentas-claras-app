# -*- coding: utf-8 -*-
"""
Tests de contrato para verificación de versión de la aplicación y descarga de APK.
"""

def test_check_latest_version_no_update(client):
    """Si la versión local es igual a la remota, update_required debe ser False."""
    # Obtenemos la última versión actual
    res_info = client.get("/api/version/latest")
    assert res_info.status_code == 200
    latest = res_info.get_json()["latest_version"]

    res = client.get(f"/api/version/latest?current_version={latest}")
    assert res.status_code == 200
    data = res.get_json()
    assert "latest_version" in data
    assert "download_url" in data
    assert data["update_required"] is False


def test_check_latest_version_update_required(client):
    """Si la versión local es menor (0.0.1 < latest), update_required debe ser True."""
    res = client.get("/api/version/latest?current_version=0.0.1")
    assert res.status_code == 200
    data = res.get_json()
    assert data["update_required"] is True
    assert "/api/version/download" in data["download_url"]


def test_download_apk_endpoint_redirects(client):
    """El endpoint /api/version/download debe devolver un redirect 302 hacia el release o asset."""
    res = client.get("/api/version/download", follow_redirects=False)
    assert res.status_code == 302
    assert "Location" in res.headers
