"""Unit tests for LoadTest API."""
import pytest
from app import app


@pytest.fixture
def client():
    """Create a test client."""
    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client


def test_health_endpoint(client):
    """Test health check returns 200 with status ok."""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.get_json()
    assert data["status"] == "ok"
    assert "hostname" in data


def test_load_valid_percent(client):
    """Test load endpoint with valid percentage."""
    # Use low percent and mock to avoid actual CPU burn in tests
    response = client.get("/1")
    assert response.status_code == 200
    data = response.get_json()
    assert data["target_cpu_percent"] == 1
    assert "duration_seconds" in data
    assert "cores_used" in data
    assert "hostname" in data


def test_load_invalid_percent_zero(client):
    """Test load endpoint rejects 0%."""
    response = client.get("/0")
    assert response.status_code == 400
    data = response.get_json()
    assert "error" in data


def test_load_invalid_percent_over_100(client):
    """Test load endpoint rejects > 100%."""
    response = client.get("/101")
    assert response.status_code == 400
    data = response.get_json()
    assert "error" in data


def test_load_boundary_1_percent(client):
    """Test minimum valid percentage."""
    response = client.get("/1")
    assert response.status_code == 200


def test_load_boundary_100_percent(client):
    """Test maximum valid percentage."""
    # This will actually burn CPU - consider mocking in real tests
    response = client.get("/100")
    assert response.status_code == 200
    data = response.get_json()
    assert data["target_cpu_percent"] == 100
