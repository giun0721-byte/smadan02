'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "7435e019a11514fa5b0150facb71fb65",
"assets/AssetManifest.bin.json": "84b2ddd045a79f6189245fa1b7b36b61",
"assets/assets/bg/bg1.jpg": "9985d031732d385f1889dd894f15b94f",
"assets/assets/bg/bg2.jpg": "b7e2acab40f7347accfd29b21616eb61",
"assets/assets/bg/bg3.jpg": "e0216b8c2eb905138cd6a646ecba0cec",
"assets/assets/bg/bg4.jpg": "3a8a80acdcb39ccc72058ff97aa70afe",
"assets/assets/bg/bg5.jpg": "7bf28fa8a7112b365812a46f86d52874",
"assets/assets/butsudan/butsudan-eva.png": "be78762f49b548af73d4fad5f2316953",
"assets/assets/butsudan/butsudan-karaki.png": "70bf93cd24b19186e0b7e6304763d995",
"assets/assets/butsudan/butsudan-modan.png": "5298e0944f16b6b46d416fd81b593d6e",
"assets/assets/effect/comet.mp4": "c7cd5d6856653be3b4a20d71681ad7ef",
"assets/assets/effect/gold-lightball.mp4": "ec8c7593e0a15c2b8f6e5a830dca890f",
"assets/assets/effect/hanabi.mp4": "165f92f313101d28fd93d59311a172af",
"assets/assets/effect/leafs.mp4": "57234e3bc5ec883f6e2b29eae80c0716",
"assets/assets/effect/leafs2.mp4": "26202afe983a43919b7eb8ad52b155bb",
"assets/assets/effect/leafs3.mp4": "3ce302a82b7df5731e5df1f74a7116f6",
"assets/assets/effect/particle1.mp4": "67cc6646681c17323403eaef9bae156a",
"assets/assets/effect/snow1.mp4": "d18be72ea8558ee5911680ca219361a3",
"assets/assets/ihai/ihai1.png": "6d1333479003c639a5f793324f72cd0e",
"assets/assets/ihai/ihai1_g.png": "47dd82749a8fc13ddb6607111c473dd1",
"assets/assets/ihai/ihai2.png": "351f1d599a652901471f4d6a03fd2d6b",
"assets/assets/ihai/ihai3_k.png": "788c675ebd712e74aa9c47a5e5ecb1ce",
"assets/assets/ihai/ihai3_s.png": "700927374383521e99f4e7f5f5b20226",
"assets/assets/ihai/ihai4_kuri.png": "a15ced3613b4c8f19219261871191d33",
"assets/assets/ihai/ihai6_eva1.png": "a0e013f53fb38ff1e3a3da6176697c01",
"assets/assets/ihai/ihai6_eva2.png": "3aaf92fcdca10adcde2f1fdc256eb30e",
"assets/assets/news/bg_report.jpg": "531d1fa00cfad4f431a5b2f669754dde",
"assets/assets/news/bg_temple.jpg": "32d456a88fca8dd73b3e537a24d8a5a8",
"assets/assets/news/news.json": "6a36b71d07af1b6cd1f9e253d361c378",
"assets/assets/news/smadan_birth.jpg": "0c9a831844a937f0262d7f6e57441d70",
"assets/assets/news/smadan_usage.jpg": "b029b297e52b1bd3380b20ddb11c9249",
"assets/assets/news/temple_ico.png": "d578fe1b37b5fc0c8b2b08849a990bc7",
"assets/assets/people.csv": "b3d6f5d911a2d1934fac18d22d89a97c",
"assets/assets/portrait/natume1.jpg": "2008e64f3db9ef518e56277567656051",
"assets/assets/portrait/natume2.jpg": "a9f9f24286a23994b5f2e6132007a950",
"assets/assets/portrait/portrait1-1.jpg": "71dbea6bd8f8171c87e412f978e488b6",
"assets/assets/portrait/portrait1.jpg": "f46e29e58f17bced07a7389f586eb433",
"assets/assets/portrait/portrait2-1.jpg": "9c2d1e772b6de40a35a2522e024f0900",
"assets/assets/portrait/portrait2.jpg": "fc86d8ea09de7cf543bac3e2b7296a80",
"assets/assets/portrait/portrait3-1.jpg": "7001aaa782da392fefce618d2f96dc2c",
"assets/assets/portrait/portrait3.jpg": "14cf70616d93b7011603d292ba8e042d",
"assets/assets/portrait/sakamoto1.jpg": "ae2f2d5fd278ad0b16f8df036dea3c50",
"assets/assets/portrait/sakamoto2.jpg": "72189cbbcc018fe856f97250570cad11",
"assets/assets/portrait/shiki1.jpg": "dd77fbb94d0140216bce3991565461be",
"assets/assets/portrait/shiki2.jpg": "204992b1203737a0e9eabe2b4b88c6f4",
"assets/assets/portrait/shiki3.jpg": "a3040af02570c117ea4b10f058dd4b96",
"assets/assets/portrait/yujiro1.jpg": "3038778aac849c8c436c87f497daaa11",
"assets/assets/portrait/yujiro2.jpg": "d7f958e5fd05151f7b9460efb5898555",
"assets/FontManifest.json": "7b2a36307916a9721811788013e65289",
"assets/fonts/MaterialIcons-Regular.otf": "86d2d7781d55485351eca06c441112cb",
"assets/NOTICES": "85c8a374f3d31d5ae47c7c83c6743f81",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/shaders/stretch_effect.frag": "40d68efbbf360632f614c731219e95f0",
"canvaskit/canvaskit.js": "8331fe38e66b3a898c4f37648aaf7ee2",
"canvaskit/canvaskit.js.symbols": "a3c9f77715b642d0437d9c275caba91e",
"canvaskit/canvaskit.wasm": "9b6a7830bf26959b200594729d73538e",
"canvaskit/chromium/canvaskit.js": "a80c765aaa8af8645c9fb1aae53f9abf",
"canvaskit/chromium/canvaskit.js.symbols": "e2d09f0e434bc118bf67dae526737d07",
"canvaskit/chromium/canvaskit.wasm": "a726e3f75a84fcdf495a15817c63a35d",
"canvaskit/skwasm.js": "8060d46e9a4901ca9991edd3a26be4f0",
"canvaskit/skwasm.js.symbols": "3a4aadf4e8141f284bd524976b1d6bdc",
"canvaskit/skwasm.wasm": "7e5f3afdd3b0747a1fd4517cea239898",
"canvaskit/skwasm_heavy.js": "740d43a6b8240ef9e23eed8c48840da4",
"canvaskit/skwasm_heavy.js.symbols": "0755b4fb399918388d71b59ad390b055",
"canvaskit/skwasm_heavy.wasm": "b0be7910760d205ea4e011458df6ee01",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"flutter.js": "24bc71911b75b5f8135c949e27a2984e",
"flutter_bootstrap.js": "3bba4b47056e2e936ef788981f2bdd78",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"index.html": "452d458c8b9fb64a533207b36958df5b",
"/": "452d458c8b9fb64a533207b36958df5b",
"main.dart.js": "b27929d48e8bd9a2ba7769713e8ada75",
"manifest.json": "1d4743100e0354fb61e831ecef4a7b2b",
"version.json": "2787b22d7ba804418629258964b210b5"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
