package com.hervoice.app.network

import retrofit2.Call
import retrofit2.http.Body
import retrofit2.http.POST

data class AuthRequest(val email: String, val password: String)
data class AuthResponse(val token: String?)

interface AuthApi {
    @POST("api/auth/register")
    fun register(@Body req: AuthRequest): Call<Map<String, String>>

    @POST("api/auth/login")
    fun login(@Body req: AuthRequest): Call<AuthResponse>
}
