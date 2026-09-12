package com.crystal_messenger.app.ui

import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.toRoute
import com.crystal_messenger.app.CrystalApp
import com.crystal_messenger.app.core.settings.Session
import com.crystal_messenger.app.di.AppContainer
import com.crystal_messenger.app.features.camera.CameraScreen
import com.crystal_messenger.app.features.chats.ChatDetailScreen
import com.crystal_messenger.app.features.chats.ContactScreen
import com.crystal_messenger.app.features.chats.GroupCreateScreen
import com.crystal_messenger.app.features.chats.NewChatScreen
import com.crystal_messenger.app.features.home.HomeScreen
import com.crystal_messenger.app.features.onboarding.OnboardingScreen
import com.crystal_messenger.app.features.profile.ProfileScreen
import com.crystal_messenger.app.features.status.PostStatusScreen
import com.crystal_messenger.app.navigation.CameraRoute
import com.crystal_messenger.app.navigation.ChatRoute
import com.crystal_messenger.app.navigation.ContactRoute
import com.crystal_messenger.app.navigation.GroupCreateRoute
import com.crystal_messenger.app.navigation.HomeRoute
import com.crystal_messenger.app.navigation.NewChatRoute
import com.crystal_messenger.app.navigation.OnboardingRoute
import com.crystal_messenger.app.navigation.PostStatusRoute
import com.crystal_messenger.app.navigation.ProfileRoute

@Composable
fun CrystalMessengerApp() {
    val context = LocalContext.current
    val container: AppContainer = remember {
        (context.applicationContext as CrystalApp).container
    }
    val session by container.sessionManager.session.collectAsStateWithLifecycle(
        initialValue = Session(),
        lifecycle = LocalLifecycleOwner.current.lifecycle
    )

    val navController = rememberNavController()

    NavHost(
        navController = navController,
        startDestination = if (session.onboarded && session.isLoggedIn) HomeRoute else OnboardingRoute
    ) {
        composable<OnboardingRoute> {
            OnboardingScreen(
                onDone = {
                    navController.navigate(HomeRoute) {
                        popUpTo(OnboardingRoute) { inclusive = true }
                    }
                }
            )
        }

        composable<HomeRoute> {
            HomeScreen(
                container = container,
                onOpenChat = { id -> navController.navigate(ChatRoute(id)) },
                onNewChat = { navController.navigate(NewChatRoute) },
                onOpenProfile = { navController.navigate(ProfileRoute) },
                onOpenGroupCreate = { navController.navigate(GroupCreateRoute) },
                onPostStatus = { navController.navigate(PostStatusRoute(null)) }
            )
        }

        composable<ChatRoute> { entry ->
            val route = entry.toRoute<ChatRoute>()
            ChatDetailScreen(
                container = container,
                conversationId = route.conversationId,
                onBack = { navController.popBackStack() },
                onOpenCamera = { id -> navController.navigate(CameraRoute(id)) },
                onOpenContact = { userId -> navController.navigate(ContactRoute(userId)) }
            )
        }

        composable<NewChatRoute> {
            NewChatScreen(
                container = container,
                onBack = { navController.popBackStack() },
                onChatCreated = { id ->
                    navController.navigate(ChatRoute(id)) {
                        popUpTo(NewChatRoute) { inclusive = true }
                    }
                },
                onOpenGroupCreate = { navController.navigate(GroupCreateRoute) }
            )
        }

        composable<ProfileRoute> {
            ProfileScreen(
                container = container,
                onBack = { navController.popBackStack() },
                onLogout = {
                    container.realtimeSynchronizer.stop()
                    navController.navigate(OnboardingRoute) {
                        popUpTo(HomeRoute) { inclusive = true }
                    }
                }
            )
        }

        composable<ContactRoute> { entry ->
            val route = entry.toRoute<ContactRoute>()
            ContactScreen(
                container = container,
                userId = route.userId,
                onBack = { navController.popBackStack() }
            )
        }

        composable<GroupCreateRoute> {
            GroupCreateScreen(
                container = container,
                onBack = { navController.popBackStack() }
            )
        }

        composable<CameraRoute> { entry ->
            val route = entry.toRoute<CameraRoute>()
            CameraScreen(
                container = container,
                conversationId = route.conversationId,
                onBack = { navController.popBackStack() },
                onMediaSent = { navController.popBackStack() }
            )
        }

        composable<PostStatusRoute> { entry ->
            val route = entry.toRoute<PostStatusRoute>()
            PostStatusScreen(
                container = container,
                mediaUri = route.mediaUri?.let { Uri.parse(it) },
                onBack = { navController.popBackStack() },
                onPosted = { navController.popBackStack() }
            )
        }
    }
}