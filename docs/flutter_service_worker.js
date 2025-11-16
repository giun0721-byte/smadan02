'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "ff6867e01d8c2aaac8a0d9e062377546",
"assets/AssetManifest.bin.json": "304b0ef00759087da3c6559885110eef",
"assets/AssetManifest.json": "b9d3d9921b1a4087c189b8bd11275095",
"assets/assets/bg/bg1.jpg": "9985d031732d385f1889dd894f15b94f",
"assets/assets/bg/bg2.jpg": "b7e2acab40f7347accfd29b21616eb61",
"assets/assets/bg/bg3.jpg": "e0216b8c2eb905138cd6a646ecba0cec",
"assets/assets/bg/bg4.jpg": "3a8a80acdcb39ccc72058ff97aa70afe",
"assets/assets/bg/bg5.jpg": "7bf28fa8a7112b365812a46f86d52874",
"assets/assets/butsudan/butsudan-eva.png": "be78762f49b548af73d4fad5f2316953",
"assets/assets/butsudan/butsudan-karaki.png": "70bf93cd24b19186e0b7e6304763d995",
"assets/assets/butsudan/butsudan-modan.png": "5298e0944f16b6b46d416fd81b593d6e",
"assets/assets/effect/leafs.mp4": "57234e3bc5ec883f6e2b29eae80c0716",
"assets/assets/effect/leafs2.mp4": "26202afe983a43919b7eb8ad52b155bb",
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
"assets/assets/news/column.html": "fb037afcfb34f648c2e7c4d6ac70205d",
"assets/assets/news/howto.html": "a9036a419105fe3e20cc38e776d89fc1",
"assets/assets/news/index.json": "839df2a8af14bf2c13d8b8c910f20fcd",
"assets/assets/news/memorial.html": "f91c72bd68ddba29eb745e2b783cbf44",
"assets/assets/news/temple.html": "3750cd217bc0561fa3e4336bba077a8b",
"assets/assets/people.csv": "44fb29d828c2ec870ba895f9e872c2b8",
"assets/assets/portrait/portrait1-1.jpg": "71dbea6bd8f8171c87e412f978e488b6",
"assets/assets/portrait/portrait1.jpg": "f46e29e58f17bced07a7389f586eb433",
"assets/assets/portrait/portrait2-1.jpg": "9c2d1e772b6de40a35a2522e024f0900",
"assets/assets/portrait/portrait2.jpg": "fc86d8ea09de7cf543bac3e2b7296a80",
"assets/assets/portrait/portrait3-1.jpg": "7001aaa782da392fefce618d2f96dc2c",
"assets/assets/portrait/portrait3.jpg": "14cf70616d93b7011603d292ba8e042d",
"assets/FontManifest.json": "7b2a36307916a9721811788013e65289",
"assets/fonts/MaterialIcons-Regular.otf": "faf14fefeb6a4c0074f0b90a77fcb969",
"assets/NOTICES": "ac5967dc600efd6350983aa817550bdb",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"canvaskit/canvaskit.js": "140ccb7d34d0a55065fbd422b843add6",
"canvaskit/canvaskit.js.symbols": "58832fbed59e00d2190aa295c4d70360",
"canvaskit/canvaskit.wasm": "07b9f5853202304d3b0749d9306573cc",
"canvaskit/chromium/canvaskit.js": "5e27aae346eee469027c80af0751d53d",
"canvaskit/chromium/canvaskit.js.symbols": "193deaca1a1424049326d4a91ad1d88d",
"canvaskit/chromium/canvaskit.wasm": "24c77e750a7fa6d474198905249ff506",
"canvaskit/skwasm.js": "1ef3ea3a0fec4569e5d531da25f34095",
"canvaskit/skwasm.js.symbols": "0088242d10d7e7d6d2649d1fe1bda7c1",
"canvaskit/skwasm.wasm": "264db41426307cfc7fa44b95a7772109",
"canvaskit/skwasm_heavy.js": "413f5b2b2d9345f37de148e2544f584f",
"canvaskit/skwasm_heavy.js.symbols": "3c01ec03b5de6d62c34e17014d1decd3",
"canvaskit/skwasm_heavy.wasm": "8034ad26ba2485dab2fd49bdd786837b",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"flutter.js": "888483df48293866f9f41d3d9274a779",
"flutter_bootstrap.js": "118636f48feb328d633a4da27312c7a6",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"index.html": "452d458c8b9fb64a533207b36958df5b",
"/": "452d458c8b9fb64a533207b36958df5b",
"main.dart.js": "6820973e29393e6abcaed70133766179",
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
