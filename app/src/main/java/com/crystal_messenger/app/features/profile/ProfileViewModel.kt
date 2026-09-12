package com.crystal_messenger.app.features.profile

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.crystal_messenger.app.core.settings.Session
import com.crystal_messenger.app.core.supabase.AuthRepository
import com.crystal_messenger.app.di.AppContainer
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

data class ProfileUiState(
    val session: Session? = null,
    val saving: Boolean = false
)

class ProfileViewModel(private val container: AppContainer) : ViewModel() {

    private val sessionManager = container.sessionManager
    private val auth: AuthRepository = container.authRepository

    private val _uiState = MutableStateFlow(ProfileUiState())
    val uiState: StateFlow<ProfileUiState> = _uiState

    init {
        viewModelScope.launch {
            _uiState.value = ProfileUiState(session = sessionManager.current())
        }
    }

    fun saveName(name: String) {
        val trimmed = name.trim().takeIf { it.isNotBlank() } ?: return
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(saving = true)
            auth.updateMyProfile(trimmed, "")
            sessionManager.updateLocalName(trimmed, "")
            _uiState.value = _uiState.value.copy(
                saving = false,
                session = sessionManager.current()
            )
        }
    }

    fun logout(onDone: () -> Unit) {
        viewModelScope.launch {
            auth.setPresence("offline")
            auth.logout()
            onDone()
        }
    }
}