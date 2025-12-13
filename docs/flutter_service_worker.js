'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "f158420ac0470cca2c344321e61ced8a",
"assets/AssetManifest.bin.json": "9f112fbe7cf3414b80b865153a47cfb2",
"assets/assets/asset_index.json": "5da2f480c3d8a21c2b8956cb8cd8c4dd",
"assets/assets/bg/01_sakura.mp4": "a12b55d1da1e9bfa8c7bb0d8f2bc7225",
"assets/assets/bg/02_grassland.mp4": "12e99bc5318cc995b7573b0ffd1cfc28",
"assets/assets/bg/bg1.jpg": "9985d031732d385f1889dd894f15b94f",
"assets/assets/bg/bg2.jpg": "b7e2acab40f7347accfd29b21616eb61",
"assets/assets/bg/bg3.jpg": "e0216b8c2eb905138cd6a646ecba0cec",
"assets/assets/bg/bg4.jpg": "3a8a80acdcb39ccc72058ff97aa70afe",
"assets/assets/bg/bg5.jpg": "7bf28fa8a7112b365812a46f86d52874",
"assets/assets/butsudan/01karaki.png": "8d5dc877a01f1cab761949031e97fed1",
"assets/assets/butsudan/01karaki_f.png": "c4fb52527f40491e419b8a203f472ca7",
"assets/assets/butsudan/02kagucho.png": "fffc6fbf85de8ede3b39f1ea0e1d7ae0",
"assets/assets/butsudan/02kagucho_f.png": "f90a52242b5ed00bc9f97eceef1023cd",
"assets/assets/butsudan/03dog.png": "531a706ff3da554e284d9057e3850f96",
"assets/assets/butsudan/04eva.png": "6d81fdb67e480aeccc0e78d10a097027",
"assets/assets/butsudan/04eva_f.png": "83ddaeb0e876c85ae65b3699c8af0cf3",
"assets/assets/butsudan/butsudan-eva.png": "a9fdabd4681042b2e640e9fabba3810b",
"assets/assets/butsudan/butsudan-karaki.png": "e8a685727ec98644fe8e2a24f3d6f152",
"assets/assets/butsudan/butsudan-modan.png": "fed3b8ddf49441a325fb950032f57966",
"assets/assets/effect/comet.mp4": "c7cd5d6856653be3b4a20d71681ad7ef",
"assets/assets/effect/gold-lightball.mp4": "ec8c7593e0a15c2b8f6e5a830dca890f",
"assets/assets/effect/hanabi.mp4": "165f92f313101d28fd93d59311a172af",
"assets/assets/effect/leafs.mp4": "57234e3bc5ec883f6e2b29eae80c0716",
"assets/assets/effect/leafs2.mp4": "26202afe983a43919b7eb8ad52b155bb",
"assets/assets/effect/leafs3.mp4": "3ce302a82b7df5731e5df1f74a7116f6",
"assets/assets/effect/particle1.mp4": "67cc6646681c17323403eaef9bae156a",
"assets/assets/effect/snow1.mp4": "d18be72ea8558ee5911680ca219361a3",
"assets/assets/ihai/eva01.png": "a0e013f53fb38ff1e3a3da6176697c01",
"assets/assets/ihai/eva02.png": "8130feffcce8448c9e22f10205986ea4",
"assets/assets/ihai/ihai01.png": "f6b917c4a57484dcbf2a8abb083e72dd",
"assets/assets/ihai/ihai02.png": "628675d69249425e1d82269bd215f93b",
"assets/assets/ihai/ihai03.png": "2308481223eb4053514078eb8571e5f4",
"assets/assets/ihai/ihai04.png": "8294d9746c2a8fd9b55bf4d469f5e540",
"assets/assets/ihai/ihai05.png": "6c9b7b62468b050f112f61251e76e38d",
"assets/assets/ihai/ihai06.png": "434f8ef55fb3cacb2ac0a957b1649717",
"assets/assets/ihai/ihai07.png": "e6e5b4c5469d4fc0015627bab84cf31b",
"assets/assets/ihai/ihai08.png": "58143d09ed33965b2d37010dea867db7",
"assets/assets/ihai/ihai09.png": "f87f5a1cfe996316b422e9723ff12c76",
"assets/assets/ihai/ihai10.png": "68905caa2efcf011924d055f17eefd6a",
"assets/assets/ihai/ihai11.png": "ccb83cafbece63c73ee1e48f082babd0",
"assets/assets/news/bg_report.jpg": "531d1fa00cfad4f431a5b2f669754dde",
"assets/assets/news/bg_temple.jpg": "32d456a88fca8dd73b3e537a24d8a5a8",
"assets/assets/news/news.json": "9cb975d811c56d596a755a204ceb953b",
"assets/assets/news/smadan_birth.jpg": "0c9a831844a937f0262d7f6e57441d70",
"assets/assets/news/smadan_set.jpg": "58fb9b495b0d87f23023343737e5510a",
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
"assets/fonts/MaterialIcons-Regular.otf": "65165d25ee0dec4bb443588aa3c6ba3d",
"assets/NOTICES": "f6c8073afd0b2954e91c984f203eff51",
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
"flutter_bootstrap.js": "3d4282bcf8156a246a29024f2dfb6520",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"index.html": "452d458c8b9fb64a533207b36958df5b",
"/": "452d458c8b9fb64a533207b36958df5b",
"main.dart.js": "d7e2fcfc7b70125fa56f36aab4817d4e",
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
