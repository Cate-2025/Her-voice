package com.hervoice.app

import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity

class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        val btnAuth = findViewById<Button>(R.id.btn_auth)
        val btnReport = findViewById<Button>(R.id.btn_report)
        val btnEvidence = findViewById<Button>(R.id.btn_evidence)

        btnAuth.setOnClickListener {
            startActivity(Intent(this, LoginActivity::class.java))
        }

        btnReport.setOnClickListener {
            startActivity(Intent(this, ReportActivity::class.java))
        }

        btnEvidence.setOnClickListener {
            startActivity(Intent(this, EvidenceVaultActivity::class.java))
        }
    }
}
