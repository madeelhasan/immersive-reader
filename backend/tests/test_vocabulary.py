def test_list_vocabulary_returns_seeded_dataset(client):
    response = client.get("/vocabulary")
    assert response.status_code == 200
    body = response.json()
    assert len(body) > 100  # seeded from the real, growing dataset

    entry = next(e for e in body if e["en"] == "house")
    assert entry["de"] == "Haus"
    assert entry["cefr_level"] == "A1"
    assert entry["part_of_speech"] == "noun"


def test_list_vocabulary_filters_by_cefr_level(client):
    response = client.get("/vocabulary", params={"cefr_level": "A1"})
    assert response.status_code == 200
    body = response.json()
    assert len(body) > 0
    assert all(e["cefr_level"] == "A1" for e in body)


def test_list_vocabulary_unknown_level_returns_empty(client):
    response = client.get("/vocabulary", params={"cefr_level": "C2"})
    assert response.status_code == 200
    assert response.json() == []
