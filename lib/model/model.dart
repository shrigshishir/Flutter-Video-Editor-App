class Layer {
  final String type; // TODO: enums
  List<Asset> assets;
  double? volume;

  Layer({required this.type, List<Asset>? assets, this.volume})
    : assets = assets ?? <Asset>[];

  Layer.clone(Layer layer)
    : type = layer.type,
      assets = layer.assets.map((asset) => Asset.clone(asset)).toList(),
      volume = layer.volume;

  Layer.fromJson(Map<String, dynamic> map)
    : type = map['type'],
      assets = map['assets'] != null
          ? List<Asset>.from(
              (map['assets'] as List).map((json) => Asset.fromJson(json)),
            )
          : <Asset>[],
      volume = map['volume'];

  Map<String, dynamic> toJson() => {
    'type': type,
    'assets': assets.map((asset) => asset.toJson()).toList(),
    'volume': volume,
  };
}

enum AssetType { video, image, text, audio }

class Asset {
  AssetType type;
  String srcPath;
  String? thumbnailPath;
  String? thumbnailMedPath;
  String title;
  int duration;
  int begin;
  int cutFrom;
  int? originalDuration; // Track original duration for constraint enforcement

  int kenBurnZSign;
  double kenBurnXTarget;
  double kenBurnYTarget;
  double x;
  double y;
  String font;
  double fontSize;
  int fontColor;
  double alpha;
  double borderw;
  int bordercolor;
  int shadowcolor;
  double shadowx;
  double shadowy;
  bool box;
  double boxborderw;
  int boxcolor;
  bool deleted;
  double?
  volume; // Volume level for video/audio assets (0.0 to 1.0, null = inherit from layer)

  Asset({
    required this.type,
    required this.srcPath,
    this.thumbnailPath,
    this.thumbnailMedPath,
    required this.title,
    required this.duration,
    required this.begin,
    this.cutFrom = 0,
    this.originalDuration,
    this.kenBurnZSign = 0,
    this.kenBurnXTarget = 0.5,
    this.kenBurnYTarget = 0.5,
    this.x = 0.1,
    this.y = 0.1,
    this.font = 'Lato/Lato-Regular.ttf',
    this.fontSize = 0.1,
    this.fontColor = 0xFFFFFFFF,
    this.alpha = 1,
    this.borderw = 0,
    this.bordercolor = 0xFFFFFFFF,
    this.shadowcolor = 0xFFFFFFFF,
    this.shadowx = 0,
    this.shadowy = 0,
    this.box = false,
    this.boxborderw = 0,
    this.boxcolor = 0x88000000,
    this.deleted = false,
    this.volume,
  });

  Asset.clone(Asset asset)
    : type = asset.type,
      srcPath = asset.srcPath,
      thumbnailPath = asset.thumbnailPath,
      thumbnailMedPath = asset.thumbnailMedPath,
      title = asset.title,
      duration = asset.duration,
      begin = asset.begin,
      cutFrom = asset.cutFrom,
      originalDuration = asset.originalDuration,
      kenBurnZSign = asset.kenBurnZSign,
      kenBurnXTarget = asset.kenBurnXTarget,
      kenBurnYTarget = asset.kenBurnYTarget,
      x = asset.x,
      y = asset.y,
      font = asset.font,
      fontSize = asset.fontSize,
      fontColor = asset.fontColor,
      alpha = asset.alpha,
      borderw = asset.borderw,
      bordercolor = asset.bordercolor,
      shadowcolor = asset.shadowcolor,
      shadowx = asset.shadowx,
      shadowy = asset.shadowy,
      box = asset.box,
      boxborderw = asset.boxborderw,
      boxcolor = asset.boxcolor,
      deleted = asset.deleted,
      volume = asset.volume;

  Asset.fromJson(Map<String, dynamic> map)
    : type = getAssetTypeFromString(map['type'])!,
      srcPath = map['srcPath'],
      thumbnailPath = map['thumbnailPath'],
      thumbnailMedPath = map['thumbnailMedPath'],
      title = map['title'],
      duration = map['duration'],
      begin = map['begin'],
      cutFrom = map['cutFrom'] ?? 0,
      originalDuration = map['originalDuration'],
      kenBurnZSign = map['kenBurnZSign'] ?? 0,
      kenBurnXTarget = (map['kenBurnXTarget'] ?? 0.5).toDouble(),
      kenBurnYTarget = (map['kenBurnYTarget'] ?? 0.5).toDouble(),
      x = (map['x'] ?? 0.1).toDouble(),
      y = (map['y'] ?? 0.1).toDouble(),
      font = map['font'] ?? 'Lato/Lato-Regular.ttf',
      fontSize = (map['fontSize'] ?? 0.1).toDouble(),
      fontColor = map['fontColor'] ?? 0xFFFFFFFF,
      alpha = (map['alpha'] ?? 1).toDouble(),
      borderw = (map['borderw'] ?? 0).toDouble(),
      bordercolor = map['bordercolor'] ?? 0xFFFFFFFF,
      shadowcolor = map['shadowcolor'] ?? 0xFFFFFFFF,
      shadowx = (map['shadowx'] ?? 0).toDouble(),
      shadowy = (map['shadowy'] ?? 0).toDouble(),
      box = map['box'] ?? false,
      boxborderw = (map['boxborderw'] ?? 0).toDouble(),
      boxcolor = map['boxcolor'] ?? 0x88000000,
      deleted = map['deleted'] ?? false,
      volume = map['volume']?.toDouble();

  Map<String, dynamic> toJson() => {
    'type': type.toString(),
    'srcPath': srcPath,
    'thumbnailPath': thumbnailPath,
    'thumbnailMedPath': thumbnailMedPath,
    'title': title,
    'duration': duration,
    'begin': begin,
    'cutFrom': cutFrom,
    'originalDuration': originalDuration,
    'kenBurnZSign': kenBurnZSign,
    'kenBurnXTarget': kenBurnXTarget,
    'kenBurnYTarget': kenBurnYTarget,
    'x': x,
    'y': y,
    'font': font,
    'fontSize': fontSize,
    'fontColor': fontColor,
    'alpha': alpha,
    'borderw': borderw,
    'bordercolor': bordercolor,
    'shadowcolor': shadowcolor,
    'shadowx': shadowx,
    'shadowy': shadowy,
    'box': box,
    'boxborderw': boxborderw,
    'boxcolor': boxcolor,
    'deleted': deleted,
    'volume': volume,
  };

  static AssetType? getAssetTypeFromString(String? assetTypeAsString) {
    if (assetTypeAsString == null) return null;
    for (AssetType element in AssetType.values) {
      if (element.toString() == assetTypeAsString) {
        return element;
      }
    }
    return null;
  }
}

class Selected {
  final int layerIndex;
  final int assetIndex;
  double dragX;
  int closestAsset;
  double initScrollOffset;
  double incrScrollOffset;

  Selected(
    this.layerIndex,
    this.assetIndex, {
    this.dragX = 0,
    this.closestAsset = -1,
    this.initScrollOffset = 0,
    this.incrScrollOffset = 0,
  });

  bool isSelected(int layerIndex, int assetIndex) {
    return (layerIndex == this.layerIndex && assetIndex == this.assetIndex);
  }
}
