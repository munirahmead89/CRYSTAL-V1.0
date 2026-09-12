package com.crystal_messenger.app.navigation

import kotlinx.serialization.Serializable

@Serializable
object OnboardingRoute

@Serializable
object HomeRoute

@Serializable
data class ChatRoute(val conversationId: String)

@Serializable
object NewChatRoute

@Serializable
object ProfileRoute

@Serializable
data class CameraRoute(val conversationId: String, val preTake: Boolean = false)

@Serializable
data class ContactRoute(val userId: String)

@Serializable
object GroupCreateRoute

@Serializable
data class PostStatusRoute(val mediaUri: String? = null)