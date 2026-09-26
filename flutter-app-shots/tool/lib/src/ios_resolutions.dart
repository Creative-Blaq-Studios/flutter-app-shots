// Portrait native pixel resolutions for store-relevant iOS simulators.
// verified: 2026-06-23 — refresh against Apple's screenshot specs when models change.
const Map<String, List<int>> kIosDeviceResolutions = {
  'iPhone 16 Pro Max': [1320, 2868],
  'iPhone 16 Plus': [1290, 2796],
  'iPhone 16 Pro': [1206, 2622],
  'iPhone 16': [1179, 2556],
  'iPhone 15 Pro Max': [1290, 2796],
  'iPhone 15 Plus': [1290, 2796],
  'iPhone SE': [750, 1334],
  'iPad Pro 13-inch (M4)': [2064, 2752],
  'iPad Pro 12.9-inch': [2048, 2732],
  'iPad Pro 11-inch': [1668, 2388],
  'iPad Air 13-inch': [2048, 2732],
  'iPad Air 11-inch': [1640, 2360],
};

/// Returns `[width, height]` (portrait) for the best matching known model name,
/// or null if no known model name is a substring of [deviceName].
/// Longest matching key wins so "iPhone 16 Pro Max" beats "iPhone 16".
List<int>? lookupIosResolution(String deviceName) {
  String? best;
  for (final key in kIosDeviceResolutions.keys) {
    if (deviceName.contains(key)) {
      if (best == null || key.length > best.length) best = key;
    }
  }
  return best == null ? null : kIosDeviceResolutions[best];
}
