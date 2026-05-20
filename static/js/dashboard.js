// Global JavaScript for Trash to Treasure Super User Dashboard
console.log('Trash to Treasure Dashboard loaded!');

// Initialize the application when DOM is ready
document.addEventListener('DOMContentLoaded', function() {
    initializeApp();
});

function initializeApp() {
    console.log('Initializing Trash to Treasure Dashboard...');
    
    // Initialize Lucide icons
    if (typeof lucide !== 'undefined') {
        lucide.createIcons();
        console.log('Lucide icons initialized');
    } else {
        console.error('Lucide library not loaded');
    }
    
    // Setup sidebar toggle
    setupSidebarToggle();
    
    // Setup notification badge updates
    setupNotifications();
    
    // Setup real-time data updates
    setupRealTimeUpdates();
    
    // Setup global search
    setupGlobalSearch();
    
    // Setup tooltips
    setupTooltips();
    
    console.log('Dashboard initialization complete');
}

function setupSidebarToggle() {
    const sidebarToggle = document.getElementById('sidebar-toggle');
    const sidebar = document.getElementById('sidebar');
    const mainContent = document.getElementById('main-content');
    
    if (sidebarToggle && sidebar && mainContent) {
        sidebarToggle.addEventListener('click', function() {
            console.log('Sidebar toggle clicked'); // Debug log
            sidebar.classList.toggle('collapsed');
            mainContent.classList.toggle('expanded');
            
            // Save sidebar state to localStorage
            const isCollapsed = sidebar.classList.contains('collapsed');
            localStorage.setItem('sidebarCollapsed', isCollapsed);
            
            // For mobile devices, add overlay functionality
            if (window.innerWidth <= 768) {
                if (!isCollapsed) {
                    // Create overlay when sidebar opens on mobile
                    createMobileOverlay();
                } else {
                    // Remove overlay when sidebar closes
                    removeMobileOverlay();
                }
            }
        });
        
        // Restore sidebar state from localStorage (only for desktop)
        if (window.innerWidth > 768) {
            const savedState = localStorage.getItem('sidebarCollapsed');
            if (savedState === 'true') {
                sidebar.classList.add('collapsed');
                mainContent.classList.add('expanded');
            }
        } else {
            // Ensure sidebar starts collapsed on mobile
            sidebar.classList.add('collapsed');
            mainContent.classList.add('expanded');
        }
        
        // Handle window resize
        window.addEventListener('resize', function() {
            if (window.innerWidth > 768) {
                removeMobileOverlay();
                // Restore desktop behavior
                const savedState = localStorage.getItem('sidebarCollapsed');
                if (savedState === 'true') {
                    sidebar.classList.add('collapsed');
                    mainContent.classList.add('expanded');
                } else {
                    sidebar.classList.remove('collapsed');
                    mainContent.classList.remove('expanded');
                }
            } else {
                // Mobile behavior - sidebar should be collapsed by default
                sidebar.classList.add('collapsed');
                mainContent.classList.add('expanded');
            }
        });
    } else {
        console.error('Sidebar toggle elements not found:', {
            toggle: !!sidebarToggle,
            sidebar: !!sidebar,
            mainContent: !!mainContent
        });
    }
}

function createMobileOverlay() {
    // Remove existing overlay if any
    removeMobileOverlay();
    
    const overlay = document.createElement('div');
    overlay.id = 'mobile-sidebar-overlay';
    overlay.style.cssText = `
        position: fixed;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        background-color: rgba(0, 0, 0, 0.5);
        z-index: 1049;
        opacity: 0;
        transition: opacity 0.3s ease;
    `;
    
    document.body.appendChild(overlay);
    
    // Trigger animation
    setTimeout(() => {
        overlay.style.opacity = '1';
    }, 10);
    
    // Close sidebar when overlay is clicked
    overlay.addEventListener('click', function() {
        const sidebar = document.getElementById('sidebar');
        const mainContent = document.getElementById('main-content');
        if (sidebar && mainContent) {
            sidebar.classList.add('collapsed');
            mainContent.classList.add('expanded');
            removeMobileOverlay();
        }
    });
}

function removeMobileOverlay() {
    const overlay = document.getElementById('mobile-sidebar-overlay');
    if (overlay) {
        overlay.style.opacity = '0';
        setTimeout(() => {
            if (overlay.parentNode) {
                overlay.parentNode.removeChild(overlay);
            }
        }, 300);
    }
}

// ─── Notifications ─────────────────────────────────────────────────────────

let _notifData = [];
let _unreadDoneTasks = [];

function setupNotifications() {
    loadNotifs();
    setInterval(loadNotifs, 30000); // poll every 30 s
}

function loadNotifs() {
    // Fetch both regular notifications and machine tasks in parallel
    Promise.all([
        fetch('/api/notifications?limit=20').then(r => r.json()).catch(() => ({ notifications: [] })),
        fetch('/api/machine_notifications').then(r => r.json()).catch(() => ({ notifications: [], pending_count: 0 }))
    ]).then(([notifData, taskData]) => {
        _notifData = notifData.notifications || [];
        const unread = _countUnread(_notifData);
        const pendingTasks = taskData.pending_count || 0;

        // Find completed tasks not yet acknowledged in the bell
        const allTasks = taskData.notifications || [];
        const readIds = _getBellReadDoneIds();
        _unreadDoneTasks = allTasks.filter(t => t.status === 'done' && !readIds.has(t.id));

        renderNotifBadge(unread + pendingTasks + _unreadDoneTasks.length);
        renderNotifList(_notifData, pendingTasks, _unreadDoneTasks);
    }).catch(err => {
        console.error('Notifications fetch error:', err);
        renderNotifList([], 0, []);
    });
}

function _getBellReadDoneIds() {
    try {
        const stored = localStorage.getItem('bellReadDoneIds');
        return new Set(stored ? JSON.parse(stored) : []);
    } catch(e) { return new Set(); }
}

function _markDoneTasksAsRead(tasks) {
    try {
        const readIds = _getBellReadDoneIds();
        tasks.forEach(t => readIds.add(t.id));
        const arr = Array.from(readIds).slice(-200);
        localStorage.setItem('bellReadDoneIds', JSON.stringify(arr));
    } catch(e) {}
}

function _countUnread(notifications) {
    const lastRead = localStorage.getItem('notif_last_read') || '';
    if (!lastRead) return notifications.length;
    return notifications.filter(n => (n.created_at || '') > lastRead).length;
}

function renderNotifBadge(count) {
    const badge = document.getElementById('notif-badge');
    if (!badge) return;
    if (count > 0) {
        badge.textContent = count > 99 ? '99+' : count;
        badge.style.display = 'block';
    } else {
        badge.style.display = 'none';
    }
}

function renderNotifList(notifications, pendingTasks, doneTasks) {
    const list = document.getElementById('notif-list');
    if (!list) return;

    let html = '';

    // Pinned: pending machine tasks
    if (pendingTasks > 0) {
        html += `<div class="notif-item" style="cursor:pointer;" onclick="window.location.href='/machine_monitor'">
            <div class="notif-icon maintenance">🔧</div>
            <div class="notif-body">
                <div class="notif-title">${pendingTasks} Machine Task${pendingTasks > 1 ? 's' : ''} Pending</div>
                <div class="notif-text">Admin${pendingTasks > 1 ? 's have' : ' has'} tasks waiting — tap to view</div>
                <div class="notif-time">Machine Monitor</div>
            </div>
            <span class="badge bg-danger align-self-center">${pendingTasks}</span>
        </div>`;
    }

    // Completed task notifications (unread)
    if (doneTasks && doneTasks.length > 0) {
        doneTasks.forEach(t => {
            const action = t.type === 'empty_machine' ? 'emptied' : 'maintained';
            const who = t.completedBy || 'Admin';
            const timeStr = _timeAgo(t.completedAt);
            const noteHtml = t.completionNote ? `: "${_esc(t.completionNote)}"` : '';
            html += `<div class="notif-item" style="cursor:pointer;" onclick="window.location.href='/machine_monitor'">
                <div class="notif-icon" style="background:#d4edda;color:#155724;">✅</div>
                <div class="notif-body">
                    <div class="notif-title">Task Completed: ${_esc(t.machineName || t.machineId || 'Machine')}</div>
                    <div class="notif-text">${_esc(who)} ${action} this machine${noteHtml}</div>
                    <div class="notif-time">${timeStr}</div>
                </div>
                <span class="badge bg-success align-self-center">Done</span>
            </div>`;
        });
    }

    if (!notifications || notifications.length === 0) {
        if (!html) html = '<div class="notif-empty">No notifications yet.</div>';
    } else {
        const icons = {
            transaction: '↕️', reward: '🎁', system: '🔔',
            maintenance: '🔧', announcement: '📢', achievement: '🏆'
        };
        html += notifications.map(n => {
            const icon = icons[n.type] || '🔔';
            const timeStr = _timeAgo(n.created_at);
            return `<div class="notif-item">
                <div class="notif-icon ${n.type}">${icon}</div>
                <div class="notif-body">
                    <div class="notif-title">${_esc(n.title)}</div>
                    <div class="notif-text">${_esc(n.body)}</div>
                    <div class="notif-time">${timeStr}</div>
                </div>
            </div>`;
        }).join('');
    }
    list.innerHTML = html;
}

function onNotifOpen() {
    _saveReadWatermark();
    _markDoneTasksAsRead(_unreadDoneTasks); // mark completed tasks as seen
    loadNotifs();
}

function markAllNotifsRead() {
    _saveReadWatermark();
    _markDoneTasksAsRead(_unreadDoneTasks);
    renderNotifBadge(0);
}

function _saveReadWatermark() {
    // Use the newest notification's created_at as the watermark, or now.
    let watermark = new Date().toISOString().slice(0, 19); // 'YYYY-MM-DDTHH:MM:SS'
    if (_notifData.length > 0 && _notifData[0].created_at) {
        watermark = _notifData[0].created_at;
    }
    localStorage.setItem('notif_last_read', watermark);
}

function _timeAgo(isoStr) {
    if (!isoStr) return '';
    try {
        let s = String(isoStr).trim()
            .replace(' ', 'T')           // 'YYYY-MM-DD HH:MM' → 'YYYY-MM-DDTHH:MM'
            .replace(/(\.\d{3})\d+/, '$1'); // truncate microseconds to milliseconds
        // Only append Z if no timezone info is already present
        const hasTimezone = /Z$|[+-]\d{2}:\d{2}$|[+-]\d{4}$/.test(s);
        if (!hasTimezone) s += 'Z';
        const d = new Date(s);
        if (isNaN(d.getTime())) return '';
        const diff = Math.floor((Date.now() - d.getTime()) / 1000);
        if (diff < 60)    return 'just now';
        if (diff < 3600)  return Math.floor(diff / 60) + 'm ago';
        if (diff < 86400) return Math.floor(diff / 3600) + 'h ago';
        return Math.floor(diff / 86400) + 'd ago';
    } catch(e) { return ''; }
}

function _esc(str) {
    const d = document.createElement('div');
    d.textContent = str;
    return d.innerHTML;
}

function setupRealTimeUpdates() {
    // Simulate real-time data updates
    if (window.location.pathname === '/dashboard' || window.location.pathname === '/') {
        updateDashboardMetrics();
        setInterval(updateDashboardMetrics, 60000); // Update every minute
    }
    
    if (window.location.pathname === '/machine_monitor') {
        updateMachineStatus();
        setInterval(updateMachineStatus, 30000); // Update every 30 seconds
    }
}

function updateDashboardMetrics() {
    // Simulate updating dashboard metrics
    const metricValues = document.querySelectorAll('.metric-value');
    metricValues.forEach(value => {
        if (Math.random() > 0.8) { // 20% chance to update
            const currentValue = parseInt(value.textContent.replace(/[^\d]/g, '')) || 0;
            const change = Math.floor(Math.random() * 5) + 1;
            const newValue = currentValue + change;
            
            // Animate the change
            animateNumberChange(value, currentValue, newValue);
        }
    });
}

function updateMachineStatus() {
    // Simulate machine status updates
    const capacityBars = document.querySelectorAll('.progress-bar');
    capacityBars.forEach(bar => {
        if (Math.random() > 0.9) { // 10% chance to update
            const currentWidth = parseInt(bar.style.width) || 0;
            const change = Math.floor(Math.random() * 10) - 5; // -5 to +5 change
            const newWidth = Math.max(0, Math.min(100, currentWidth + change));
            
            bar.style.width = newWidth + '%';
            
            // Update color based on capacity
            bar.className = 'progress-bar ' + 
                (newWidth >= 90 ? 'bg-danger' : newWidth >= 70 ? 'bg-warning' : 'bg-success');
        }
    });
}

function animateNumberChange(element, startValue, endValue) {
    const duration = 1000; // 1 second animation
    const startTime = performance.now();
    
    function updateNumber(currentTime) {
        const elapsed = currentTime - startTime;
        const progress = Math.min(elapsed / duration, 1);
        
        const currentValue = Math.floor(startValue + (endValue - startValue) * progress);
        element.textContent = currentValue;
        
        if (progress < 1) {
            requestAnimationFrame(updateNumber);
        }
    }
    
    requestAnimationFrame(updateNumber);
}

function setupGlobalSearch() {
    const searchInput = document.querySelector('.search-input');
    if (searchInput) {
        searchInput.addEventListener('keypress', function(e) {
            if (e.key === 'Enter') {
                performGlobalSearch(this.value);
            }
        });
        
        // Add search button functionality
        const searchButton = document.querySelector('.search-container button');
        if (searchButton) {
            searchButton.addEventListener('click', function() {
                performGlobalSearch(searchInput.value);
            });
        }
    }
}

function performGlobalSearch(query) {
    if (!query.trim()) return;
    
    console.log('Performing global search for:', query);
    
    // In a real application, this would search across all data
    // For now, we'll show a simple alert
    alert(`Searching for: "${query}"\n\nThis would search across:\n- Users\n- Transactions\n- Rewards\n- Machines\n- Reports`);
}

function setupTooltips() {
    // Initialize Bootstrap tooltips if available
    if (typeof bootstrap !== 'undefined' && bootstrap.Tooltip) {
        const tooltipTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'));
        tooltipTriggerList.map(function (tooltipTriggerEl) {
            return new bootstrap.Tooltip(tooltipTriggerEl);
        });
    }
}

// Utility functions
function formatNumber(num) {
    return new Intl.NumberFormat().format(num);
}

function formatCurrency(amount) {
    return new Intl.NumberFormat('en-US', {
        style: 'currency',
        currency: 'USD'
    }).format(amount);
}

function formatDate(date) {
    return new Intl.DateTimeFormat('en-US', {
        year: 'numeric',
        month: 'short',
        day: 'numeric'
    }).format(new Date(date));
}

function formatTime(date) {
    return new Intl.DateTimeFormat('en-US', {
        hour: '2-digit',
        minute: '2-digit'
    }).format(new Date(date));
}

// Global notification system
function showNotification(message, type = 'info', duration = 5000) {
    const notification = document.createElement('div');
    notification.className = `alert alert-${type} alert-dismissible fade show position-fixed`;
    notification.style.cssText = 'top: 80px; right: 20px; z-index: 9999; min-width: 300px;';
    
    notification.innerHTML = `
        ${message}
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `;
    
    document.body.appendChild(notification);
    
    // Auto-dismiss after duration
    setTimeout(() => {
        if (notification.parentNode) {
            notification.remove();
        }
    }, duration);
}

// Global loading state management
function showLoading(message = 'Loading...') {
    const loading = document.createElement('div');
    loading.id = 'globalLoading';
    loading.className = 'position-fixed top-0 start-0 w-100 h-100 d-flex align-items-center justify-content-center';
    loading.style.cssText = 'background: rgba(0,0,0,0.5); z-index: 99999;';
    
    loading.innerHTML = `
        <div class="bg-white p-4 rounded shadow text-center">
            <div class="spinner-border text-primary mb-2" role="status"></div>
            <div>${message}</div>
        </div>
    `;
    
    document.body.appendChild(loading);
}

function hideLoading() {
    const loading = document.getElementById('globalLoading');
    if (loading) {
        loading.remove();
    }
}

// Export functions for global use
window.TrashToTreasure = {
    showNotification,
    showLoading,
    hideLoading,
    formatNumber,
    formatCurrency,
    formatDate,
    formatTime
};

// Handle offline/online status
window.addEventListener('online', function() {
    showNotification('Connection restored!', 'success');
});

window.addEventListener('offline', function() {
    showNotification('Connection lost. Some features may not work.', 'warning');
});

// Keyboard shortcuts
document.addEventListener('keydown', function(e) {
    // Ctrl/Cmd + K for global search
    if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
        e.preventDefault();
        const searchInput = document.querySelector('.search-input');
        if (searchInput) {
            searchInput.focus();
        }
    }
    
    // Escape to close modals
    if (e.key === 'Escape') {
        const openModal = document.querySelector('.modal.show');
        if (openModal) {
            const modalInstance = bootstrap.Modal.getInstance(openModal);
            if (modalInstance) {
                modalInstance.hide();
            }
        }
    }
});

// Page visibility change handler
document.addEventListener('visibilitychange', function() {
    if (document.hidden) {
        console.log('Page is now hidden');
        // Pause non-essential updates when page is hidden
    } else {
        console.log('Page is now visible');
        // Resume updates when page becomes visible
        if (typeof lucide !== 'undefined') {
            lucide.createIcons();
        }
    }
});

// Error handling for uncaught errors
window.addEventListener('error', function(e) {
    console.error('Global error:', e.error);
    showNotification('An unexpected error occurred. Please refresh the page.', 'danger');
});

// Service worker registration (for future PWA features)
if ('serviceWorker' in navigator) {
    window.addEventListener('load', function() {
        // navigator.serviceWorker.register('/sw.js')
        //     .then(function(registration) {
        //         console.log('SW registered: ', registration);
        //     })
        //     .catch(function(registrationError) {
        //         console.log('SW registration failed: ', registrationError);
        //     });
    });
}
