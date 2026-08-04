import { View, Text, FlatList, Keyboard, Alert, StyleSheet, KeyboardAvoidingView, Platform } from 'react-native';
import { useRouter, useLocalSearchParams } from 'expo-router';
import { useRef, useEffect, useState, useCallback } from 'react';
import { Ionicons } from '@expo/vector-icons';

import { Screen } from '@/components/Screen';
import { Button } from '@/components/Button';
import { Avatar } from '@/components/Avatar';
import { Input } from '@/components/Input';
import { Colors, Spacing, Typography, BorderRadius } from '@/theme';
import { useAuth } from '@/hooks/useAuth';
import { useChats } from '@/hooks/useChats';
import { useMessages, type MessageWithSender } from '@/hooks/useMessages';

function formatMsgTime(dateStr: string): string {
  const d = new Date(dateStr);
  return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}

export default function ChatScreen() {
  const router = useRouter();
  const params = useLocalSearchParams();
  const chatId = params.id as string;
  const { user } = useAuth();

  const { chats } = useChats(user?.id);
  const {
    messages,
    loading,
    sendMessage,
    markAsRead,
    handleKeyPress,
    otherParticipantTyping,
    otherParticipantPresence,
  } = useMessages(chatId, user?.id);

  const [text, setText] = useState('');
  const flatListRef = useRef<FlatList<MessageWithSender>>(null);
  const [keyboardHeight, setKeyboardHeight] = useState(0);

  const chat = chats.find((c) => c.id === chatId);
  const otherParticipant = chat?.otherParticipant;
  const participantId = otherParticipant?.id;

  const displayName = otherParticipant?.full_name || chat?.name || 'Chat';
  const avatarUrl = otherParticipant?.avatar_url;

  // Resolve presence dynamically
  const presenceInfo = participantId ? otherParticipantPresence[participantId] : null;
  const isOnline = presenceInfo ? presenceInfo.isOnline : (otherParticipant?.is_online ?? false);

  // Resolve typing status dynamically
  const isOtherTyping = participantId ? otherParticipantTyping[participantId] : false;

  useEffect(() => {
    const showSub = Keyboard.addListener('keyboardDidShow', (e) => {
      setKeyboardHeight(e.endCoordinates.height);
    });
    const hideSub = Keyboard.addListener('keyboardDidHide', () => {
      setKeyboardHeight(0);
    });
    return () => {
      showSub.remove();
      hideSub.remove();
    };
  }, []);

  useEffect(() => {
    if (!user?.id || messages.length === 0) return;
    const unreadIds = messages
      .filter((m) => m.sender_id !== user.id)
      .map((m) => m.id);
    if (unreadIds.length > 0) {
      void markAsRead(unreadIds);
    }
  }, [messages, user?.id, markAsRead]);

  const handleSend = useCallback(async () => {
    if (!text.trim()) return;
    const content = text;
    setText('');
    await sendMessage(content);
    setTimeout(() => {
      flatListRef.current?.scrollToEnd({ animated: true });
    }, 100);
  }, [text, sendMessage]);

  const scrollToBottom = useCallback(() => {
    flatListRef.current?.scrollToEnd({ animated: true });
  }, []);

  useEffect(() => {
    scrollToBottom();
  }, [messages, scrollToBottom]);

  const renderMessage = ({ item }: { item: MessageWithSender }) => {
    const isOwn = item.sender_id === user?.id;
    const isPending = item.status === 'pending' || item.status === 'sending';

    const statusIcon = () => {
      if (!isOwn) return null;
      if (item.status === 'pending') return '🕐';
      if (item.status === 'sending') return '↑';
      if (item.status === 'failed') return '⚠️';
      return item.is_edited ? '✓✓ (edited)' : '✓✓';
    };

    return (
      <View style={[styles.messageRow, isOwn ? styles.messageRowOwn : styles.messageRowOther, isPending && styles.messagePending]}>
        <View style={[styles.messageBubble, isOwn ? styles.bubbleOut : styles.bubbleIn]}>
          {item.is_deleted ? (
            <Text style={styles.deletedText}>This message was deleted</Text>
          ) : (
            <Text style={styles.messageText}>{item.content}</Text>
          )}
          <View style={styles.messageMeta}>
            <Text style={styles.messageTime}>{formatMsgTime(item.created_at)}</Text>
            {isOwn && (
              <Text style={styles.checkMarks}>{statusIcon()}</Text>
            )}
          </View>
        </View>
      </View>
    );
  };

  return (
    <Screen
      scrollable={false}
      padding="none"
      safeArea={true}
      style={styles.screen}
    >
      <View style={styles.header}>
        <Button variant="ghost" size="sm" onPress={() => router.back()} style={styles.backBtn}>
          <Ionicons name="arrow-back" size={22} color="#FFFFFF" />
        </Button>

        <View style={styles.headerCenter}>
          <View style={styles.avatarWrapper}>
            <Avatar
              source={avatarUrl ? { uri: avatarUrl } : undefined}
              name={displayName}
              size="sm"
            />
            {isOnline && <View style={styles.onlineDot} />}
          </View>
          <View style={styles.headerInfo}>
            <Text style={styles.contactName}>{displayName}</Text>
            {isOtherTyping ? (
              <Text style={styles.typingText}>typing...</Text>
            ) : isOnline ? (
              <Text style={styles.onlineText}>Online</Text>
            ) : (
              <Text style={styles.offlineText}>Offline</Text>
            )}
          </View>
        </View>

        <View style={styles.headerActions}>
          <Button variant="ghost" size="sm" onPress={() => Alert.alert('Video Call', 'Coming soon')} style={styles.actionBtn}>
            <Ionicons name="videocam" size={22} color="#FFFFFF" />
          </Button>
          <Button variant="ghost" size="sm" onPress={() => Alert.alert('Voice Call', 'Coming soon')} style={styles.actionBtn}>
            <Ionicons name="call" size={20} color="#FFFFFF" />
          </Button>
        </View>
      </View>

      <View style={styles.headerBorder} />

      <FlatList
        ref={flatListRef}
        data={messages}
        renderItem={renderMessage}
        keyExtractor={(item) => item.id}
        contentContainerStyle={styles.messagesContainer}
        keyboardShouldPersistTaps="handled"
        onContentSizeChange={scrollToBottom}
        ListEmptyComponent={
          !loading ? (
            <View style={styles.emptyChat}>
              <Text style={styles.emptyChatText}>No messages yet</Text>
              <Text style={styles.emptyChatSubtext}>Send a message to start the conversation</Text>
            </View>
          ) : null
        }
      />

      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        keyboardVerticalOffset={0}
      >
        <View style={styles.inputBar}>
          <Button variant="ghost" size="sm" onPress={() => {}} style={styles.emojiBtn}>
            <Ionicons name="happy-outline" size={24} color="#8696A0" />
          </Button>

          <View style={styles.inputFieldWrapper}>
            <Input
              placeholder="Message"
              value={text}
              onChangeText={(value) => {
                setText(value);
                handleKeyPress();
              }}
              onSubmitEditing={() => { void handleSend(); }}
              containerStyle={styles.inputFieldContainer}
              inputStyle={styles.inputField}
            />
          </View>

          <Button variant="ghost" size="sm" onPress={() => {}} style={styles.clipBtn}>
            <Ionicons name="attach" size={24} color="#8696A0" />
          </Button>

          <Button variant="ghost" size="sm" onPress={() => {}} style={styles.cameraBtn}>
            <Ionicons name="camera" size={24} color="#8696A0" />
          </Button>

          {text.trim() ? (
            <Button
              variant="ghost"
              size="sm"
              onPress={() => { void handleSend(); }}
              style={styles.sendBtn}
            >
              <Ionicons name="send" size={20} color="#FFFFFF" />
            </Button>
          ) : (
            <Button variant="ghost" size="sm" onPress={() => {}} style={styles.micBtn}>
              <Ionicons name="mic" size={24} color="#8696A0" />
            </Button>
          )}
        </View>
        <View style={{ height: keyboardHeight > 0 ? Spacing.sm : Spacing.xs }} />
      </KeyboardAvoidingView>
    </Screen>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: Colors.light.background,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: Spacing.xs,
    paddingVertical: Spacing.sm,
    backgroundColor: Colors.light.surface,
  },
  backBtn: {
    padding: Spacing.xs,
    minWidth: 36,
    minHeight: 36,
  },
  headerCenter: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
    marginLeft: Spacing.xs,
    gap: Spacing.sm,
  },
  avatarWrapper: {
    position: 'relative',
  },
  onlineDot: {
    position: 'absolute',
    bottom: 0,
    right: 0,
    width: 10,
    height: 10,
    borderRadius: 5,
    backgroundColor: Colors.light.onlineIndicator,
    borderWidth: 1.5,
    borderColor: Colors.light.surface,
  },
  headerInfo: {
    gap: 1,
  },
  contactName: {
    fontSize: Typography.fontSize.md,
    fontWeight: Typography.fontWeight.semibold,
    color: Colors.light.text,
  },
  onlineText: {
    fontSize: Typography.fontSize.xs,
    color: Colors.light.success,
  },
  offlineText: {
    fontSize: Typography.fontSize.xs,
    color: Colors.light.textSecondary,
  },
  typingText: {
    fontSize: Typography.fontSize.xs,
    color: Colors.light.primary,
    fontStyle: 'italic',
  },
  headerActions: {
    flexDirection: 'row',
    gap: Spacing.xs,
  },
  actionBtn: {
    padding: Spacing.xs,
    minWidth: 36,
    minHeight: 36,
  },
  headerBorder: {
    height: 0.5,
    backgroundColor: Colors.light.border,
  },
  messagesContainer: {
    flexGrow: 1,
    backgroundColor: Colors.light.background,
    paddingHorizontal: Spacing.sm,
    paddingVertical: Spacing.sm,
  },
  messageRow: {
    flexDirection: 'row',
    marginBottom: 2,
  },
  messageRowOwn: {
    justifyContent: 'flex-end',
  },
  messageRowOther: {
    justifyContent: 'flex-start',
  },
  messagePending: {
    opacity: 0.6,
  },
  messageBubble: {
    maxWidth: '80%',
    paddingHorizontal: Spacing.sm,
    paddingVertical: Spacing.xs + 2,
    borderRadius: BorderRadius.sm,
  },
  bubbleOut: {
    backgroundColor: Colors.light.chatBubbleOutgoing,
    borderTopRightRadius: BorderRadius.xs,
  },
  bubbleIn: {
    backgroundColor: Colors.light.chatBubbleIncoming,
    borderTopLeftRadius: BorderRadius.xs,
  },
  messageText: {
    fontSize: Typography.fontSize.sm,
    color: Colors.light.onSurface,
    lineHeight: Typography.lineHeight.sm,
  },
  deletedText: {
    fontSize: Typography.fontSize.sm,
    fontStyle: 'italic',
    color: Colors.light.textTertiary,
  },
  messageMeta: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    alignItems: 'center',
    marginTop: 2,
    gap: 4,
  },
  messageTime: {
    fontSize: 10,
    color: Colors.light.textTertiary,
  },
  checkMarks: {
    fontSize: 10,
    color: Colors.light.textTertiary,
  },
  inputBar: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Colors.light.surface,
    paddingHorizontal: Spacing.xs + 1,
    paddingVertical: Spacing.xs + 2,
    gap: Spacing.xs,
  },
  emojiBtn: {
    padding: Spacing.xs,
    minWidth: 36,
    minHeight: 36,
  },
  inputFieldWrapper: {
    flex: 1,
  },
  inputFieldContainer: {
    backgroundColor: Colors.light.surfaceVariant,
    borderRadius: BorderRadius.round,
    borderWidth: 0,
    paddingHorizontal: Spacing.sm,
    minHeight: 38,
  },
  inputField: {
    backgroundColor: 'transparent',
    color: Colors.light.text,
    fontSize: Typography.fontSize.sm,
    borderWidth: 0,
    paddingHorizontal: 0,
    paddingVertical: Spacing.xs,
  },
  clipBtn: {
    padding: Spacing.xs,
    minWidth: 36,
    minHeight: 36,
  },
  cameraBtn: {
    padding: Spacing.xs,
    minWidth: 36,
    minHeight: 36,
  },
  sendBtn: {
    width: 40,
    height: 40,
    borderRadius: BorderRadius.round,
    backgroundColor: Colors.light.primary,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 0,
  },
  micBtn: {
    padding: Spacing.xs,
    minWidth: 36,
    minHeight: 36,
  },
  emptyChat: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingTop: 100,
  },
  emptyChatText: {
    fontSize: Typography.fontSize.lg,
    fontWeight: Typography.fontWeight.semibold,
    color: Colors.light.text,
    marginBottom: Spacing.xs,
  },
  emptyChatSubtext: {
    fontSize: Typography.fontSize.md,
    color: Colors.light.textSecondary,
  },
});
