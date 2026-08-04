import { supabase } from '@/database/client';
import type { PostgrestError } from '@supabase/supabase-js';

export interface RepositoryError extends Error {
  code: string;
  status?: number;
  details?: string;
  hint?: string;
}

export class BaseRepository<T extends { id: string }> {
  protected tableName: string;
  protected supabase = supabase;

  constructor(tableName: string) {
    this.tableName = tableName;
  }

  protected handleError(error: PostgrestError | Error): never {
    const repositoryError: RepositoryError = new Error(error.message) as RepositoryError;
    repositoryError.code = 'POSTGREST_ERROR';
    repositoryError.status = (error as PostgrestError).code ? parseInt((error as PostgrestError).code!) : undefined;
    repositoryError.details = (error as PostgrestError).details;
    repositoryError.hint = (error as PostgrestError).hint;
    throw repositoryError;
  }

  protected handleUnknownError(error: unknown): never {
    const repositoryError: RepositoryError = new Error(
      error instanceof Error ? error.message : 'Unknown error occurred'
    ) as RepositoryError;
    repositoryError.code = 'UNKNOWN_ERROR';
    throw repositoryError;
  }

  async findById(id: string): Promise<T | null> {
    try {
      const { data, error } = await this.supabase
        .from(this.tableName)
        .select('*')
        .eq('id', id)
        .single();

      if (error) {
        if (error.code === 'PGRST116') {
          return null;
        }
        this.handleError(error);
      }

      return data as T;
    } catch (error) {
      if (error instanceof Error && 'code' in error && (error as RepositoryError).code === 'POSTGREST_ERROR') {
        throw error;
      }
      this.handleUnknownError(error);
    }
  }

  async findAll(options?: {
    limit?: number;
    offset?: number;
    orderBy?: { column: string; ascending?: boolean };
    filters?: Record<string, any>;
  }): Promise<T[]> {
    try {
      let query = this.supabase.from(this.tableName).select('*');

      if (options?.filters) {
        Object.entries(options.filters).forEach(([key, value]) => {
          query = query.eq(key, value);
        });
      }

      if (options?.orderBy) {
        query = query.order(options.orderBy.column, { ascending: options.orderBy.ascending ?? false });
      }

      if (options?.limit) {
        query = query.limit(options.limit);
      }

      if (options?.offset) {
        query = query.range(options.offset, options.offset + (options.limit || 100) - 1);
      }

      const { data, error } = await query;

      if (error) {
        this.handleError(error);
      }

      return (data as T[]) || [];
    } catch (error) {
      if (error instanceof Error && 'code' in error && (error as RepositoryError).code === 'POSTGREST_ERROR') {
        throw error;
      }
      this.handleUnknownError(error);
    }
  }

  async create(item: Omit<T, 'id' | 'created_at' | 'updated_at'> & { id: string }): Promise<T> {
    try {
      const now = new Date().toISOString();
      const insertData = {
        ...item,
        created_at: now,
        updated_at: now,
      };

      const { data, error } = await this.supabase
        .from(this.tableName)
        .insert(insertData)
        .select()
        .single();

      if (error) {
        this.handleError(error);
      }

      return data as T;
    } catch (error) {
      if (error instanceof Error && 'code' in error && (error as RepositoryError).code === 'POSTGREST_ERROR') {
        throw error;
      }
      this.handleUnknownError(error);
    }
  }

  async update(id: string, updates: Partial<Omit<T, 'id' | 'created_at'>>): Promise<T> {
    try {
      const now = new Date().toISOString();
      const updateData = {
        ...updates,
        updated_at: now,
      };

      const { data, error } = await this.supabase
        .from(this.tableName)
        .update(updateData)
        .eq('id', id)
        .select()
        .single();

      if (error) {
        this.handleError(error);
      }

      return data as T;
    } catch (error) {
      if (error instanceof Error && 'code' in error && (error as RepositoryError).code === 'POSTGREST_ERROR') {
        throw error;
      }
      this.handleUnknownError(error);
    }
  }

  async delete(id: string): Promise<void> {
    try {
      const { error } = await this.supabase.from(this.tableName).delete().eq('id', id);

      if (error) {
        this.handleError(error);
      }
    } catch (error) {
      if (error instanceof Error && 'code' in error && (error as RepositoryError).code === 'POSTGREST_ERROR') {
        throw error;
      }
      this.handleUnknownError(error);
    }
  }

  async count(filters?: Record<string, any>): Promise<number> {
    try {
      let query = this.supabase.from(this.tableName).select('*', { count: 'exact', head: true });

      if (filters) {
        Object.entries(filters).forEach(([key, value]) => {
          query = query.eq(key, value);
        });
      }

      const { count, error } = await query;

      if (error) {
        this.handleError(error);
      }

      return count || 0;
    } catch (error) {
      if (error instanceof Error && 'code' in error && (error as RepositoryError).code === 'POSTGREST_ERROR') {
        throw error;
      }
      this.handleUnknownError(error);
    }
  }

  async exists(id: string): Promise<boolean> {
    try {
      const { data, error } = await this.supabase
        .from(this.tableName)
        .select('id')
        .eq('id', id)
        .single();

      if (error) {
        if (error.code === 'PGRST116') {
          return false;
        }
        this.handleError(error);
      }

      return !!data;
    } catch (error) {
      if (error instanceof Error && 'code' in error && (error as RepositoryError).code === 'POSTGREST_ERROR') {
        throw error;
      }
      this.handleUnknownError(error);
    }
  }
}