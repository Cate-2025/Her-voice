def test_login_submit_officer_update_and_notification(client, accounts, payload):
    def login(email):
        response = client.post('/api/v1/auth/login', json={
            'email': email, 'password': 'fictional-password'})
        assert response.status_code == 200
        return {'Authorization': 'Bearer ' + response.json()['access_token']}
    student = login('student@example.test')
    officer = login('officer@example.test')
    draft = client.post('/api/v1/reports/drafts', json=payload, headers=student)
    assert draft.status_code == 201
    report_id = draft.json()['id']
    assert client.get('/api/v1/officer/cases', headers=officer).json() == []
    assert client.post(f'/api/v1/reports/{report_id}/submit', headers=student).status_code == 200
    assert client.get('/api/v1/officer/cases', headers=officer).json()[0]['id'] == report_id
    assert client.patch(f'/api/v1/officer/cases/{report_id}/status',
                        json={'status': 'received'}, headers=officer).status_code == 200
    assert client.get('/api/v1/cases/mine', headers=student).json()[0]['status'] == 'received'
    notice = client.get('/api/v1/notifications', headers=student).json()[0]
    assert 'narrative' not in notice and payload['subject_staff_ref'] not in notice['body']
    path = f"/api/v1/notifications/{notice['id']}/read"
    assert client.post(path, headers=accounts['other']['headers']).status_code == 404
    assert client.post(path, headers=student).json()['read_at'] is not None


def test_browser_preflight_is_restricted(client):
    headers = {'Origin': 'http://127.0.0.1:8765',
               'Access-Control-Request-Method': 'POST',
               'Access-Control-Request-Headers': 'authorization,content-type'}
    response = client.options('/api/v1/auth/login', headers=headers)
    assert response.status_code == 200
    assert response.headers['access-control-allow-origin'] == headers['Origin']
    headers['Origin'] = 'https://untrusted.example'
    assert client.options('/api/v1/auth/login', headers=headers).status_code == 400


def test_student_status_history_has_dates_without_actor_identity(client, accounts, payload):
    student,officer=accounts['student']['headers'],accounts['officer']['headers']
    report_id=client.post('/api/v1/reports/drafts',json=payload,headers=student).json()['id']
    client.post(f'/api/v1/reports/{report_id}/submit',headers=student)
    for status in ('received','under_review'):
        client.patch(f'/api/v1/officer/cases/{report_id}/status',json={'status':status},headers=officer)
    history=client.get(f'/api/v1/reports/{report_id}',headers=student).json()['status_history']
    assert [event['status'] for event in history] == ['submitted','received','under_review']
    assert all(set(event) == {'status','occurred_at'} for event in history)
