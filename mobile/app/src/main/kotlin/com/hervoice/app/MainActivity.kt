package com.hervoice.app

import android.os.Bundle
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
            // TODO: navigate to incident reporting screen
            Toast.makeText(this, "Incident reporting (todo)", Toast.LENGTH_SHORT).show()
        }

        btnEvidence.setOnClickListener {
            // TODO: navigate to evidence vault screen
            Toast.makeText(this, "Evidence vault (todo)", Toast.LENGTH_SHORT).show()
        }
    }
}
