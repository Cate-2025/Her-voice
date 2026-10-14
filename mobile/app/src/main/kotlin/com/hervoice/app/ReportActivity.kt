package com.hervoice.app

import android.content.Context
import android.os.Bundle
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import com.hervoice.app.network.ApiClient
import com.hervoice.app.network.IncidentReport
import com.hervoice.app.network.ReportApi
import retrofit2.Call
import retrofit2.Callback
import retrofit2.Response

class ReportActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_report)

        val etPerson = findViewById<EditText>(R.id.et_person)
        val etCourse = findViewById<EditText>(R.id.et_course)
        val etLocation = findViewById<EditText>(R.id.et_location)
        val etDescription = findViewById<EditText>(R.id.et_description)
        val etWitnesses = findViewById<EditText>(R.id.et_witnesses)
        val rgConfidentiality = findViewById<RadioGroup>(R.id.rg_confidentiality)
        val btnSubmit = findViewById<Button>(R.id.btn_submit_report)

        val reportApi = ApiClient.retrofit.create(ReportApi::class.java)

        btnSubmit.setOnClickListener {
            val person = etPerson.text.toString().trim()
            val course = etCourse.text.toString().trim()
            val location = etLocation.text.toString().trim()
            val description = etDescription.text.toString().trim()
            val witnesses = etWitnesses.text.toString().trim()

            if (person.isEmpty() || course.isEmpty() || location.isEmpty() || description.isEmpty()) {
                Toast.makeText(this, "Please fill in all core fields", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }

            val reportingType = when (rgConfidentiality.checkedRadioButtonId) {
                R.id.rb_confidential -> "CONFIDENTIAL"
                R.id.rb_anonymous -> "ANONYMOUS"
                else -> "IDENTIFIED"
            }

            val prefs = getSharedPreferences("hervoice_prefs", Context.MODE_PRIVATE)
            val token = prefs.getString("auth_token", null)
            if (token == null) {
                Toast.makeText(this, "Please login first", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }

            val report = IncidentReport(
                person = person,
                course = course,
                location = location,
                description = description,
                witnesses = if (witnesses.isEmpty()) null else witnesses,
                reportingType = reportingType
            )

            btnSubmit.isEnabled = false
            reportApi.submitReport("Bearer $token", report).enqueue(object : Callback<Map<String, Any>> {
                override fun onResponse(call: Call<Map<String, Any>>, response: Response<Map<String, Any>>) {
                    btnSubmit.isEnabled = true
                    if (response.isSuccessful) {
                        Toast.makeText(this@ReportActivity, "Incident submitted successfully", Toast.LENGTH_LONG).show()
                        finish()
                    } else {
                        Toast.makeText(this@ReportActivity, "Failed to submit: ${response.code()}", Toast.LENGTH_SHORT).show()
                    }
                }

                override fun onFailure(call: Call<Map<String, Any>>, t: Throwable) {
                    btnSubmit.isEnabled = true
                    Toast.makeText(this@ReportActivity, "Network/Offline Error: Saved as Local Draft", Toast.LENGTH_LONG).show()
                    // Simulation of offline-first storage requirement
                    saveLocalDraft(report)
                    finish()
                }
            })
        }
    }

    private fun saveLocalDraft(report: IncidentReport) {
        val prefs = getSharedPreferences("hervoice_drafts", Context.MODE_PRIVATE)
        val count = prefs.getInt("draft_count", 0)
        prefs.edit().apply {
            putInt("draft_count", count + 1)
            putString("draft_${count}_person", report.person)
            putString("draft_${count}_course", report.course)
            putString("draft_${count}_location", report.location)
            putString("draft_${count}_description", report.description)
            putString("draft_${count}_type", report.reportingType)
            apply()
        }
    }
}
