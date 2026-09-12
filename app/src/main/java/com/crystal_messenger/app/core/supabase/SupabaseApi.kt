package com.crystal_messenger.app.core.supabase

import okhttp3.RequestBody
import retrofit2.Response
import retrofit2.http.Body
import retrofit2.http.DELETE
import retrofit2.http.GET
import retrofit2.http.Header
import retrofit2.http.PATCH
import retrofit2.http.POST
import retrofit2.http.Path
import retrofit2.http.Query
import retrofit2.http.QueryMap

interface SupabaseApi {

    @POST("auth/v1/signup")
    suspend fun signup(
        @Header("apikey") apikey: String,
        @Body body: RequestBody
    ): Response<String>

    @POST("auth/v1/token")
    suspend fun token(
        @Header("apikey") apikey: String,
        @Query("grant_type") grantType: String,
        @Body body: RequestBody
    ): Response<String>

    @POST("auth/v1/refresh")
    suspend fun refreshToken(
        @Header("apikey") apikey: String,
        @Body body: RequestBody
    ): Response<String>

    @GET("rest/v1/{table}")
    suspend fun select(
        @Header("apikey") apikey: String,
        @Header("Authorization") authorization: String,
        @Path("table") table: String,
        @Query("select") select: String,
        @QueryMap filters: Map<String, String>,
        @Query("order") order: String?,
        @Query("limit") limit: Int?,
        @Query("offset") offset: Int?
    ): Response<String>

    @POST("rest/v1/{table}")
    suspend fun insert(
        @Header("apikey") apikey: String,
        @Header("Authorization") authorization: String,
        @Header("Prefer") prefer: String,
        @Path("table") table: String,
        @Query("select") select: String,
        @QueryMap filters: Map<String, String>,
        @Body body: RequestBody
    ): Response<String>

    @PATCH("rest/v1/{table}")
    suspend fun update(
        @Header("apikey") apikey: String,
        @Header("Authorization") authorization: String,
        @Header("Prefer") prefer: String,
        @Path("table") table: String,
        @QueryMap filters: Map<String, String>,
        @Body body: RequestBody
    ): Response<String>

    @DELETE("rest/v1/{table}")
    suspend fun delete(
        @Header("apikey") apikey: String,
        @Header("Authorization") authorization: String,
        @Header("Prefer") prefer: String,
        @Path("table") table: String,
        @QueryMap filters: Map<String, String>
    ): Response<String>

    @POST("rest/v1/rpc/{fn}")
    suspend fun rpc(
        @Header("apikey") apikey: String,
        @Header("Authorization") authorization: String,
        @Path("fn") fn: String,
        @Body body: RequestBody
    ): Response<String>

    @POST("storage/v1/object/{bucket}/{filePath}")
    suspend fun upload(
        @Header("apikey") apikey: String,
        @Header("Authorization") authorization: String,
        @Header("Content-Type") contentType: String,
        @Path("bucket") bucket: String,
        @Path(value = "filePath", encoded = true) filePath: String,
        @Body body: RequestBody
    ): Response<String>
}