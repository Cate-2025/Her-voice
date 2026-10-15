package com.hervoice.app.network

import retrofit2.Call
import retrofit2.http.Body
import retrofit2.http.Header
import retrofit2.http.POST
import retrofit2.http.GET

data class IncidentReport(
    val id: Long? = null,
    val person: String,
    val course: String,
    val location: String,
    val description: String,
    val witnesses: String?,
    val reportingType: String, // "IDENTIFIED", "CONFIDENTIAL", "ANONYMOUS"
    val timestamp: Long? = null,
    val status: String? = "PENDING"
)

interface ReportApi {
    @POST("api/reports")
    fun submitReport(
        @Header("Authorization") token: String,
        @Body report: IncidentReport
    ): Call<Map<String, Any>>

    @GET("api/reports")
    fun getReports(
        @Header("Authorization") token: String
    ): Call<List<IncidentReport>>
}
