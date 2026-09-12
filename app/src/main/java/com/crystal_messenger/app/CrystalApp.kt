package com.crystal_messenger.app

import android.app.Application
import com.crystal_messenger.app.di.AppContainer
import com.crystal_messenger.app.services.CallNotifier

class CrystalApp : Application() {

    lateinit var container: AppContainer
        private set

    private val callNotifier by lazy { CallNotifier(container, this) }

    override fun onCreate() {
        super.onCreate()
        container = AppContainer.get(this)
        container.realtimeSynchronizer.start()
        callNotifier.start()
    }
}