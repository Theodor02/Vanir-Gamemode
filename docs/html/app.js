
// Sidebar filter
document.addEventListener('DOMContentLoaded', function() {
    var search = document.getElementById('search');
    if (!search) return;

    search.addEventListener('input', function() {
        var query = this.value.toLowerCase().trim();
        var items = document.querySelectorAll('.nav-list li');
        items.forEach(function(item) {
            var link = item.querySelector('a');
            var searchText = link ? (link.getAttribute('data-search') || link.textContent.toLowerCase()) : '';
            item.style.display = (!query || searchText.indexOf(query) !== -1) ? '' : 'none';
        });

        // Hide headings with no visible items
        var headings = document.querySelectorAll('.nav-heading');
        headings.forEach(function(heading) {
            var list = heading.nextElementSibling;
            if (list && list.classList.contains('nav-list')) {
                var visibleItems = list.querySelectorAll('li[style=""], li:not([style])');
                heading.style.display = visibleItems.length > 0 ? '' : 'none';
            }
        });
    });

    // In-page function search
    var wrapper = document.querySelector('.wrapper');
    if (wrapper) {
        var blocks = wrapper.querySelectorAll('.function-block');
        search.addEventListener('input', function() {
            var query = this.value.toLowerCase().trim();
            if (!query || blocks.length === 0) {
                blocks.forEach(function(b) { b.style.display = ''; });
                return;
            }
            blocks.forEach(function(block) {
                var sig = block.querySelector('.sig');
                var text = sig ? sig.textContent.toLowerCase() : '';
                var id = block.id ? block.id.toLowerCase() : '';
                block.style.display = (text.indexOf(query) !== -1 || id.indexOf(query) !== -1) ? '' : 'none';
            });
        });
    }
});
