const String callVideoProfile = String.fromEnvironment(
  'CALL_VIDEO_PROFILE',
  defaultValue: 'standard',
);

Map<String, dynamic> videoCaptureConstraints({
  String profile = callVideoProfile,
}) {
  final low = profile == 'low';
  return <String, dynamic>{
    'width': {'ideal': low ? 640 : 1280},
    'height': {'ideal': low ? 480 : 720},
    'frameRate': {'ideal': low ? 24 : 30},
  };
}
