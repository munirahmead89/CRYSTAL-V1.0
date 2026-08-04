import { supabase } from '@/database/client';
import { StorageRepository } from '../StorageRepository';

jest.mock('@/database/client', () => ({
  supabase: {
    storage: {
      from: jest.fn(),
    },
  },
}));

describe('StorageRepository', () => {
  const uploadMock = jest.fn();
  const getPublicUrlMock = jest.fn();

  beforeEach(() => {
    jest.clearAllMocks();
    (supabase.storage.from as jest.Mock).mockReturnValue({
      upload: uploadMock,
      getPublicUrl: getPublicUrlMock,
    });

    // Mock global.fetch
    global.fetch = jest.fn().mockImplementation(() =>
      Promise.resolve({
        blob: () => Promise.resolve({ size: 1024, type: 'image/jpeg' }),
      })
    ) as any;
  });

  it('uploads avatar successfully and returns public URL with cache buster', async () => {
    uploadMock.mockResolvedValue({ data: { path: 'user-1/avatar.jpg' }, error: null });
    getPublicUrlMock.mockReturnValue({ data: { publicUrl: 'https://example.com/avatar.jpg' } });

    const repo = new StorageRepository();
    const result = await repo.uploadAvatar('user-1', 'file://path/to/avatar.jpg');

    expect(result).toContain('https://example.com/avatar.jpg?t=');
    expect(global.fetch).toHaveBeenCalledWith('file://path/to/avatar.jpg');
    expect(supabase.storage.from).toHaveBeenCalledWith('avatars');
    expect(uploadMock).toHaveBeenCalledWith('user-1/avatar.jpg', expect.any(Object), {
      contentType: 'image/jpeg',
      upsert: true,
    });
    expect(getPublicUrlMock).toHaveBeenCalledWith('user-1/avatar.jpg');
  });

  it('throws error when upload fails', async () => {
    uploadMock.mockResolvedValue({ data: null, error: new Error('Upload error') });

    const repo = new StorageRepository();
    await expect(repo.uploadAvatar('user-1', 'file://path/to/avatar.jpg')).rejects.toThrow('Upload error');
  });
});
