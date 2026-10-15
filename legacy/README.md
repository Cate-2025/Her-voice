# Historical implementations

`main/` preserves the backend, Flutter client, Android client and tooling from remote main commit `38b13df` during the 15 October 2026 consolidation. It is retained for traceability and selective porting, not as another supported deployment.

Run the root `flutter_app/` and FastAPI `backend/` instead. The archived Flutter client's Node `/api` contract is incompatible with the active FastAPI `/api/v1` contract. Its offline queue and other features require review against the original security requirements before reuse.
