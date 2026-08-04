import AsyncStorage from '@react-native-async-storage/async-storage';
import { supabase } from '@/database/client';
import { logger } from '@/utils/logger';
import { generateId } from '@/utils/id';

interface QueuedOperation {
  id: string;
  type: 'create' | 'update' | 'delete';
  table: string;
  data: any;
  timestamp: number;
  retries: number;
  maxRetries: number;
}

interface OfflineMessage {
  id: string;
  chatId: string;
  content: string;
  messageType: string;
  replyToId?: string;
  attachments?: any[];
  timestamp: number;
  status: 'pending' | 'sending' | 'sent' | 'failed';
  localId: string;
}

const STORAGE_KEYS = {
  OPERATIONS_QUEUE: 'offline_operations_queue',
  MESSAGES_QUEUE: 'offline_messages_queue',
  LAST_SYNC: 'last_sync_timestamp',
} as const;

class OfflineStorage {
  private operationsQueue: QueuedOperation[] = [];
  private messagesQueue: OfflineMessage[] = [];
  private isInitialized = false;
  private syncInterval: ReturnType<typeof setInterval> | null = null;

  async initialize(): Promise<void> {
    if (this.isInitialized) return;

    try {
      const [operations, messages] = await Promise.all([
        AsyncStorage.getItem(STORAGE_KEYS.OPERATIONS_QUEUE),
        AsyncStorage.getItem(STORAGE_KEYS.MESSAGES_QUEUE),
      ]);

      this.operationsQueue = operations ? JSON.parse(operations) : [];
      this.messagesQueue = messages ? JSON.parse(messages) : [];

      this.isInitialized = true;
      logger.info('Offline storage initialized', {
        operationsCount: this.operationsQueue.length,
        messagesCount: this.messagesQueue.length,
      });
    } catch (error) {
      logger.error('Failed to initialize offline storage', {}, error as Error);
      this.operationsQueue = [];
      this.messagesQueue = [];
      this.isInitialized = true;
    }
  }

  private async saveOperationsQueue(): Promise<void> {
    try {
      await AsyncStorage.setItem(STORAGE_KEYS.OPERATIONS_QUEUE, JSON.stringify(this.operationsQueue));
    } catch (error) {
      logger.error('Failed to save operations queue', {}, error as Error);
    }
  }

  private async saveMessagesQueue(): Promise<void> {
    try {
      await AsyncStorage.setItem(STORAGE_KEYS.MESSAGES_QUEUE, JSON.stringify(this.messagesQueue));
    } catch (error) {
      logger.error('Failed to save messages queue', {}, error as Error);
    }
  }

  async queueOperation(operation: Omit<QueuedOperation, 'id' | 'timestamp' | 'retries'>): Promise<void> {
    await this.initialize();

    const queuedOperation: QueuedOperation = {
      ...operation,
      id: generateId(),
      timestamp: Date.now(),
      retries: 0,
    };

    this.operationsQueue.push(queuedOperation);
    await this.saveOperationsQueue();

    logger.debug('Operation queued', { operation: queuedOperation });
  }

  async queueMessage(message: Omit<OfflineMessage, 'id' | 'timestamp' | 'status' | 'localId'>): Promise<string> {
    await this.initialize();

    const localId = generateId();
    const offlineMessage: OfflineMessage = {
      ...message,
      id: generateId(),
      localId,
      timestamp: Date.now(),
      status: 'pending',
    };

    this.messagesQueue.push(offlineMessage);
    await this.saveMessagesQueue();

    logger.debug('Message queued', { message: offlineMessage });
    return localId;
  }

  async updateMessageStatus(localId: string, status: OfflineMessage['status']): Promise<void> {
    await this.initialize();

    const index = this.messagesQueue.findIndex((m) => m.localId === localId);
    const message = this.messagesQueue[index];
    if (message) {
      message.status = status;
      await this.saveMessagesQueue();
    }
  }

  async getPendingMessages(): Promise<OfflineMessage[]> {
    await this.initialize();
    return this.messagesQueue.filter((m) => m.status === 'pending' || m.status === 'failed');
  }

  async getPendingOperations(): Promise<QueuedOperation[]> {
    await this.initialize();
    return this.operationsQueue.filter((op) => op.retries < op.maxRetries);
  }

  async removeOperation(id: string): Promise<void> {
    await this.initialize();
    this.operationsQueue = this.operationsQueue.filter((op) => op.id !== id);
    await this.saveOperationsQueue();
  }

  async removeMessage(localId: string): Promise<void> {
    await this.initialize();
    this.messagesQueue = this.messagesQueue.filter((m) => m.localId !== localId);
    await this.saveMessagesQueue();
  }

  async incrementOperationRetries(id: string): Promise<void> {
    await this.initialize();
    const operation = this.operationsQueue.find((op) => op.id === id);
    if (operation) {
      operation.retries++;
      await this.saveOperationsQueue();
    }
  }

  async sync(): Promise<void> {
    await this.initialize();

    const isOnline = await this.checkConnectivity();
    if (!isOnline) {
      logger.debug('Skipping sync - offline');
      return;
    }

    logger.info('Starting offline sync');

    await this.syncOperations();
    await this.syncMessages();

    await AsyncStorage.setItem(STORAGE_KEYS.LAST_SYNC, Date.now().toString());
    logger.info('Offline sync completed');
  }

  private async checkConnectivity(): Promise<boolean> {
    try {
      const { error } = await supabase.from('profiles').select('id').limit(1);
      return !error;
    } catch {
      return false;
    }
  }

  private async syncOperations(): Promise<void> {
    const operations = await this.getPendingOperations();

    for (const operation of operations) {
      try {
        let error: any = null;

        switch (operation.type) {
          case 'create':
            ({ error } = await supabase.from(operation.table).insert(operation.data));
            break;
          case 'update':
            ({ error } = await supabase.from(operation.table).update(operation.data).eq('id', operation.data.id));
            break;
          case 'delete':
            ({ error } = await supabase.from(operation.table).delete().eq('id', operation.data.id));
            break;
        }

        if (error) {
          throw error;
        }

        await this.removeOperation(operation.id);
        logger.debug('Operation synced', { operationId: operation.id });
      } catch (error) {
        await this.incrementOperationRetries(operation.id);
        logger.warn('Operation sync failed', { operationId: operation.id, retries: operation.retries }, error as Error);
      }
    }
  }

  private async syncMessages(): Promise<void> {
    const messages = await this.getPendingMessages();

    for (const message of messages) {
      try {
        await this.updateMessageStatus(message.localId, 'sending');

        const { data, error } = await supabase.rpc('send_message', {
          chat_id: message.chatId,
          content: message.content,
          message_type: message.messageType,
          reply_to_id: message.replyToId,
          metadata: { attachments: message.attachments },
        });

        if (error) {
          throw error;
        }

        await this.removeMessage(message.localId);
        logger.debug('Message synced', { localId: message.localId, serverId: data });
      } catch (error) {
        await this.updateMessageStatus(message.localId, 'failed');
        logger.warn('Message sync failed', { localId: message.localId }, error as Error);
      }
    }
  }

  async getLastSyncTime(): Promise<number | null> {
    try {
      const time = await AsyncStorage.getItem(STORAGE_KEYS.LAST_SYNC);
      return time ? parseInt(time, 10) : null;
    } catch {
      return null;
    }
  }

  async clear(): Promise<void> {
    this.operationsQueue = [];
    this.messagesQueue = [];
    await Promise.all([
      AsyncStorage.removeItem(STORAGE_KEYS.OPERATIONS_QUEUE),
      AsyncStorage.removeItem(STORAGE_KEYS.MESSAGES_QUEUE),
      AsyncStorage.removeItem(STORAGE_KEYS.LAST_SYNC),
    ]);
    logger.info('Offline storage cleared');
  }

  startPeriodicSync(intervalMs = 30000): void {
    if (this.syncInterval) {
      clearInterval(this.syncInterval);
    }
    this.syncInterval = setInterval(() => this.sync(), intervalMs);
  }

  stopPeriodicSync(): void {
    if (this.syncInterval) {
      clearInterval(this.syncInterval);
      this.syncInterval = null;
    }
  }
}

export const offlineStorage = new OfflineStorage();