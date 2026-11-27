# SYNC_CoinInsert の配布

`make_release_zip.bat` はリリース用の `SYNC_CoinInsert.auf2` をまとめ、`SYNC_CoinInsert.catalog.json` の末尾の版に同じ AUF2 の XXH3-128 を記録します。

- AUF2 の既定の場所は `C:\ProgramData\aviutl2\Plugin\SYNC_CoinInsert` です。別の場所を使う場合は `-ReleaseDirectory` で指定します。
- `xxhsum.exe` は `Win64\Dependencies\xxHash-0.8.4` に置くか、PATH または `-XxhsumPath` で指定します。[xxHash 公式配布](https://github.com/Cyan4973/xxHash/releases/tag/v0.8.4)
- 初回配布は `v1.0.0` です。カタログの版・公開日と、本体の表示バージョンを公開内容に合わせます。

```bat
Setup\make_release_zip.bat -ReleaseDirectory "D:\Release\SYNC_CoinInsert"
```

出力先は `Setup\SYNC_CoinInsert.zip` です。ZIP の `SYNC_CoinInsert/` に、AUF2、README、ライセンス、共通基盤のライセンス表示を収録します。カタログは同じフォルダーを単位としてインストールとアンインストールを行います。

公開タグには README が参照する `Sample/coin-insert.png` を含め、リリースに ZIP と `SYNC_CoinInsert.catalog.json` を添付します。
