package com.crystal_messenger.app.features.onboarding

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.crystal_messenger.app.di.AppContainer
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class OnboardingUiState(
    val name: String = "",
    val phone: String = "",
    val loading: Boolean = false,
    val error: String? = null
)

class OnboardingViewModel(private val container: AppContainer) : ViewModel() {

    private val _state = MutableStateFlow(OnboardingUiState())
    val state: StateFlow<OnboardingUiState> = _state.asStateFlow()

    fun setName(name: String) = _state.update { it.copy(name = name) }

    fun setPhone(phone: String) = _state.update { it.copy(phone = phone) }

    fun signUp(onDone: () -> Unit) {
        val s = _state.value
        if (s.name.isBlank() || s.phone.filter { it.isDigit() }.length < 8) {
            _state.update { it.copy(error = "Enter a valid name and phone number.") }
            return
        }
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            try {
                container.authRepository.signUp(s.phone.trim(), s.name.trim())
                container.chatRepository.syncConversations(sessionUserId())
                container.realtimeSynchronizer.start()
                _state.update { it.copy(loading = false) }
                onDone()
            } catch (e: Exception) {
                _state.update {
                    it.copy(loading = false, error = e.message ?: "Could not connect. Check your internet.")
                }
            }
        }
    }

    private suspend fun sessionUserId(): String = container.sessionManager.current().userId.orEmpty()
}