package com.crystal_messenger.app.features.home

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ChatBubble
import androidx.compose.material.icons.rounded.Call
import androidx.compose.material.icons.rounded.DonutSmall
import androidx.compose.material.icons.rounded.Groups
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.crystal_messenger.app.di.AppContainer
import com.crystal_messenger.app.features.calls.CallsScreen
import com.crystal_messenger.app.features.chats.ChatsScreen
import com.crystal_messenger.app.features.communities.CommunitiesScreen
import com.crystal_messenger.app.features.status.StatusScreen

private data class TabSpec(val label: String, val icon: androidx.compose.ui.graphics.vector.ImageVector, val onClick: () -> Unit)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    container: AppContainer,
    onOpenChat: (String) -> Unit,
    onNewChat: () -> Unit,
    onOpenProfile: () -> Unit,
    onOpenGroupCreate: () -> Unit,
    onPostStatus: () -> Unit
) {
    var selectedTab by rememberSaveable { mutableIntStateOf(0) }

    val tabs = listOf(
        TabSpec("Chats", Icons.Rounded.ChatBubble, {}),
        TabSpec("Status", Icons.Rounded.DonutSmall, {}),
        TabSpec("Communities", Icons.Rounded.Groups, {}),
        TabSpec("Calls", Icons.Rounded.Call, {})
    )

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = if (selectedTab == 0) "Crystal" else tabs[selectedTab].label,
                        style = MaterialTheme.typography.titleLarge
                    )
                },
                actions = {
                    Icon(
                        Icons.Rounded.Search,
                        contentDescription = "Search",
                        modifier = Modifier.padding(horizontal = 4.dp)
                    )
                },
                modifier = Modifier.padding(end = 8.dp)
            )
        },
        bottomBar = {
            NavigationBar {
                tabs.forEachIndexed { index, tab ->
                    NavigationBarItem(
                        selected = selectedTab == index,
                        onClick = {
                            selectedTab = index
                            tab.onClick()
                        },
                        icon = { Icon(tab.icon, contentDescription = tab.label) },
                        label = { Text(tab.label) }
                    )
                }
            }
        }
    ) { padding ->
        Box(Modifier.fillMaxSize().padding(padding)) {
            when (selectedTab) {
                0 -> ChatsScreen(
                    container = container,
                    onOpenChat = onOpenChat,
                    onNewChat = onNewChat,
                    onOpenProfile = onOpenProfile
                )
                1 -> StatusScreen(
                    container = container,
                    onPostStatus = onPostStatus
                )
                2 -> CommunitiesScreen(
                    container = container,
                    onCreateGroup = onOpenGroupCreate
                )
                3 -> CallsScreen(container = container)
            }
        }
    }
}