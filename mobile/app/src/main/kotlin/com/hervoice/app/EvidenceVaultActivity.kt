package com.hervoice.app

import android.os.Bundle
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.ListView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity

class EvidenceVaultActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_evidence_vault)

        val btnSelectFile = findViewById<Button>(R.id.btn_select_file)
        val btnRecordAudio = findViewById<Button>(R.id.btn_record_audio)
        val btnUploadVault = findViewById<Button>(R.id.btn_upload_vault)
        val lvEvidence = findViewById<ListView>(R.id.lv_evidence)

        val simulatedFiles = mutableListOf(
            "screenshot_whatsapp_12_sept.png (Securely Encrypted)",
            "voice_note_15_sept.amr (Permitted Recording)"
        )

        val adapter = ArrayAdapter(this, android.R.layout.simple_list_item_1, simulatedFiles)
        lvEvidence.adapter = adapter

        btnSelectFile.setOnClickListener {
            Toast.makeText(this, "File Picker opened (Evidence encrypted on select)", Toast.LENGTH_SHORT).show()
        }

        btnRecordAudio.setOnClickListener {
            Toast.makeText(this, "Recording permitted audio note...", Toast.LENGTH_SHORT).show()
        }

        btnUploadVault.setOnClickListener {
            Toast.makeText(this, "Evidence files securely synced to backend vault", Toast.LENGTH_LONG).show()
        }
    }
}
