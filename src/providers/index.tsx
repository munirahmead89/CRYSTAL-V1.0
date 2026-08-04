import { Providers as QueryProviders } from '@/providers/QueryProvider';
import type { ReactNode} from 'react';
import { useEffect } from 'react';
import { initializeAuthListener } from '@/database/client';
import { startNetworkMonitoring } from '@/services/network/networkDetection';
import { offlineStorage } from '@/services/offline/offlineStorage';
import { logger } from '@/utils/logger';

export function Providers({ children }: { children: ReactNode }) {
  useEffect(() => {
    logger.info('Initializing app providers');

    const cleanupAuth = initializeAuthListener();
    const cleanupNetwork = startNetworkMonitoring();

    offlineStorage.initialize().then(() => {
      offlineStorage.startPeriodicSync(30000);
    });

    return () => {
      cleanupAuth();
      cleanupNetwork();
      offlineStorage.stopPeriodicSync();
      logger.info('App providers cleaned up');
    };
  }, []);

  return <QueryProviders>{children}</QueryProviders>;
}