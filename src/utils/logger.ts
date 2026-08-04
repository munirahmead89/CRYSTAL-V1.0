type LogLevel = 'debug' | 'info' | 'warn' | 'error';

interface LogEntry {
  timestamp: string;
  level: LogLevel;
  message: string;
  context?: Record<string, any>;
  error?: Error;
}

class Logger {
  private logs: LogEntry[] = [];
  private maxLogs = 1000;
  private minLevel: LogLevel = __DEV__ ? 'debug' : 'info';

  private shouldLog(level: LogLevel): boolean {
    const levels: LogLevel[] = ['debug', 'info', 'warn', 'error'];
    return levels.indexOf(level) >= levels.indexOf(this.minLevel);
  }

  private formatMessage(level: LogLevel, message: string, context?: Record<string, any>, error?: Error): string {
    const timestamp = new Date().toISOString();
    const contextStr = context ? ` ${JSON.stringify(context)}` : '';
    const errorStr = error ? ` ${error.stack || error.message}` : '';
    return `[${timestamp}] [${level.toUpperCase()}] ${message}${contextStr}${errorStr}`;
  }

  private addLog(entry: LogEntry): void {
    this.logs.push(entry);
    if (this.logs.length > this.maxLogs) {
      this.logs.shift();
    }
  }

  debug(message: string, context?: Record<string, any>): void {
    if (!this.shouldLog('debug')) return;
    const entry: LogEntry = { timestamp: new Date().toISOString(), level: 'debug', message, context };
    this.addLog(entry);
    console.debug(this.formatMessage('debug', message, context));
  }

  info(message: string, context?: Record<string, any>): void {
    if (!this.shouldLog('info')) return;
    const entry: LogEntry = { timestamp: new Date().toISOString(), level: 'info', message, context };
    this.addLog(entry);
    console.info(this.formatMessage('info', message, context));
  }

  warn(message: string, context?: Record<string, any>, error?: Error): void {
    if (!this.shouldLog('warn')) return;
    const entry: LogEntry = { timestamp: new Date().toISOString(), level: 'warn', message, context, error };
    this.addLog(entry);
    console.warn(this.formatMessage('warn', message, context, error));
  }

  error(message: string, context?: Record<string, any>, error?: Error): void {
    if (!this.shouldLog('error')) return;
    const entry: LogEntry = { timestamp: new Date().toISOString(), level: 'error', message, context, error };
    this.addLog(entry);
    console.error(this.formatMessage('error', message, context, error));
  }

  getLogs(level?: LogLevel): LogEntry[] {
    if (!level) return [...this.logs];
    return this.logs.filter((log) => log.level === level);
  }

  clearLogs(): void {
    this.logs = [];
  }

  setMinLevel(level: LogLevel): void {
    this.minLevel = level;
  }

  exportLogs(): string {
    return this.logs.map((log) => this.formatMessage(log.level, log.message, log.context, log.error)).join('\n');
  }
}

export const logger = new Logger();

export function createScopedLogger(scope: string) {
  return {
    debug: (message: string, context?: Record<string, any>) => logger.debug(`[${scope}] ${message}`, context),
    info: (message: string, context?: Record<string, any>) => logger.info(`[${scope}] ${message}`, context),
    warn: (message: string, context?: Record<string, any>, error?: Error) => logger.warn(`[${scope}] ${message}`, context, error),
    error: (message: string, context?: Record<string, any>, error?: Error) => logger.error(`[${scope}] ${message}`, context, error),
  };
}