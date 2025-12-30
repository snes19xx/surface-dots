(function () {
    function waitForElement(els, func, timeout = 100) {
        const queries = els.map(el => document.querySelector(el));
        if (queries.every(a => a)) {
            func(queries);
        } else if (timeout > 0) {
            setTimeout(waitForElement, 300, els, func, --timeout);
        }
    }

    document.body.classList.add("everforest");
    if (!document.getElementById('glow')) {
        const style = document.createElement('style');
        style.id = 'glow';
        style.innerHTML = `
            .Root__main-view::before {
                content: '';
                position: absolute;
                top: 0; left: 0; right: 0; height: 300px;
                background: linear-gradient(180deg, rgba(131, 192, 146, 0.05) 0%, transparent 100%);
                pointer-events: none;
                z-index: 0;
            }
        `;
        document.head.appendChild(style);
    }

    waitForElement([`ul[tabindex="0"]`], ([root]) => {
        function loadPlaylistImage() {
            const items = root.querySelectorAll("li"); 
            for (const item of items) {
                let link = item.querySelector("a");
                if (!link || link.querySelector(".playlist-picture")) continue;

                let path = link.pathname.split("/");
                let app = path[1];
                let uid = path[2];

                if (app === "playlist") {
                    let uri = `spotify:playlist:${uid}`;
                    Spicetify.CosmosAsync.get(`sp://core-playlist/v1/playlist/${uri}/metadata`, { policy: { picture: true } }).then(res => {
                        if (res && res.metadata && res.metadata.picture) {
                            let img = document.createElement("img");
                            img.classList.add("playlist-picture");
                            img.src = res.metadata.picture;
                            img.style.borderRadius = "50%"; // Circular sidebar icons
                            img.style.width = "24px";
                            img.style.height = "24px";
                            img.style.marginRight = "12px";
                            img.style.objectFit = "cover";
                            link.prepend(img);
                        }
                    });
                }
            }
        }
        
        // Watch for changes (scrolling/loading more playlists)
        new MutationObserver(loadPlaylistImage).observe(root, { childList: true, subtree: true });
        // Run once on load
        loadPlaylistImage();
    });
})();