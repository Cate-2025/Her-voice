import 'dart:io';

import 'draft_vault.dart';
import 'encrypted_draft_vault.dart';

DraftVault? createDraftVault() =>
    Platform.isAndroid ? EncryptedDraftVault() : null;
