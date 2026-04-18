abstract class CloudSyncService {
  Future<String> currentStatusLabel();

  Future<void> prepareSync();
}

class PlaceholderCloudSyncService implements CloudSyncService {
  const PlaceholderCloudSyncService();

  @override
  Future<String> currentStatusLabel() async {
    return 'クラウド同期準備済み（Supabase連携待ち）';
  }

  @override
  Future<void> prepareSync() async {
    // Supabase Auth / Sync 導入前のプレースホルダ
  }
}
