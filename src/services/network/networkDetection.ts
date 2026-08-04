import type { NetInfoState, NetInfoSubscription } from '@react-native-community/netinfo';
import NetInfo from '@react-native-community/netinfo';
import { useNetworkStore } from '@/stores';
import { logger } from '@/utils/logger';

let netInfoSubscription: NetInfoSubscription | null = null;
let isMonitoring = false;

export function startNetworkMonitoring(): () => void {
  if (isMonitoring) {
    return stopNetworkMonitoring;
  }

  isMonitoring = true;

  netInfoSubscription = NetInfo.addEventListener((state: NetInfoState) => {
    const isConnected = state.isConnected ?? false;
    const connectionType = state.type || 'unknown';

    useNetworkStore.getState().setConnected(isConnected);
    useNetworkStore.getState().setConnectionType(
      connectionType === 'wifi' ? 'wifi' : connectionType === 'cellular' ? 'cellular' : 'unknown'
    );

    logger.info('Network state changed', { isConnected, connectionType });

    if (isConnected) {
      import('@/services/offline/offlineStorage').then(({ offlineStorage }) => {
        offlineStorage.sync();
      });
    }
  });

  return stopNetworkMonitoring;
}

export function stopNetworkMonitoring(): void {
  if (netInfoSubscription) {
    netInfoSubscription();
    netInfoSubscription = null;
  }
  isMonitoring = false;
}

export async function getCurrentNetworkState(): Promise<NetInfoState> {
  return NetInfo.fetch();
}

export async function isConnected(): Promise<boolean> {
  const state = await NetInfo.fetch();
  return state.isConnected ?? false;
}

export function useNetworkListener(): void {
  // This hook can be used in components to ensure network monitoring is active
  // The actual state is managed by the global store
}