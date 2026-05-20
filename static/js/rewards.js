/**
 * Rewards Management JavaScript
 * Handles CRUD operations and filtering for rewards
 */

// Global variables for modals
let editModal, restockModal, deleteModal;

document.addEventListener('DOMContentLoaded', function() {
    // Reinitialize Lucide icons
    setTimeout(() => {
        lucide.createIcons();
    }, 100);

    // Initialize modals
    initializeModals();

    // ===== ADD REWARD =====
    const addRewardBtn = document.querySelector('#addRewardModal .btn-primary');
    if (addRewardBtn) {
        addRewardBtn.addEventListener('click', async function() {
            const form = document.getElementById('addRewardForm');
            if (!form.checkValidity()) {
                form.reportValidity();
                return;
            }

            const data = {
                name: document.getElementById('rewardName').value.trim(),
                department: document.getElementById('rewardDepartment').value,
                cost: parseInt(document.getElementById('rewardPoints').value),
                stock: parseInt(document.getElementById('rewardStock').value)
            };

            try {
                const response = await fetch('/api/rewards/add', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify(data)
                });

                const result = await response.json();
                
                if (result.success) {
                    alert('Reward added successfully!');
                    location.reload();
                } else {
                    alert('Error: ' + result.message);
                }
            } catch (error) {
                alert('Error adding reward: ' + error.message);
            }
        });
    }

    // ===== EDIT REWARD =====
    document.querySelectorAll('.edit-reward-btn').forEach(btn => {
        btn.addEventListener('click', async function() {
            const rewardId = this.getAttribute('data-reward-id');
            
            try {
                const response = await fetch(`/api/rewards/get/${rewardId}`);
                const result = await response.json();
                
                if (result.success) {
                    const reward = result.reward;
                    showEditModal(reward);
                }
            } catch (error) {
                alert('Error loading reward: ' + error.message);
            }
        });
    });

    // ===== RESTOCK REWARD =====
    document.querySelectorAll('.restock-reward-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            const rewardId = this.getAttribute('data-reward-id');
            const rewardName = this.getAttribute('data-reward-name');
            showRestockModal(rewardId, rewardName);
        });
    });

    // ===== DELETE REWARD =====
    document.querySelectorAll('.delete-reward-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            const rewardId = this.getAttribute('data-reward-id');
            const rewardName = this.getAttribute('data-reward-name');
            showDeleteModal(rewardId, rewardName);
        });
    });

    // ===== SEARCH FUNCTIONALITY =====
    const searchInput = document.getElementById('searchRewards');
    if (searchInput) {
        searchInput.addEventListener('input', function() {
            applyFilters();
        });
    }

    // ===== FILTER FUNCTIONALITY =====
    function applyFilters() {
        const searchTerm = document.getElementById('searchRewards').value.toLowerCase();
        const departmentFilter = document.getElementById('filterDepartment').value.toLowerCase();
        const statusFilter = document.getElementById('filterStatus').value;
        const pointsFilter = document.getElementById('filterPoints').value;
        
        const rows = document.querySelectorAll('#rewardsTableBody tr[data-reward-id]');
        
        rows.forEach(row => {
            const name = row.getAttribute('data-name').toLowerCase();
            const department = row.getAttribute('data-department').toLowerCase();
            const status = row.getAttribute('data-status');
            const points = parseInt(row.getAttribute('data-points'));
            
            let show = true;
            
            // Search filter
            if (searchTerm && !name.includes(searchTerm) && !department.includes(searchTerm)) {
                show = false;
            }
            
            // Department filter
            if (departmentFilter && !department.includes(departmentFilter)) {
                show = false;
            }
            
            // Status filter
            if (statusFilter && status !== statusFilter) {
                show = false;
            }
            
            // Points filter
            if (pointsFilter) {
                if (pointsFilter === '0-50' && (points < 0 || points > 50)) show = false;
                if (pointsFilter === '51-100' && (points < 51 || points > 100)) show = false;
                if (pointsFilter === '101-200' && (points < 101 || points > 200)) show = false;
                if (pointsFilter === '200+' && points <= 200) show = false;
            }
            
            row.style.display = show ? '' : 'none';
        });
    }

    // Attach filter event listeners
    const filterDepartment = document.getElementById('filterDepartment');
    const filterStatus = document.getElementById('filterStatus');
    const filterPoints = document.getElementById('filterPoints');
    
    if (filterDepartment) filterDepartment.addEventListener('change', applyFilters);
    if (filterStatus) filterStatus.addEventListener('change', applyFilters);
    if (filterPoints) filterPoints.addEventListener('change', applyFilters);

    // ===== CLEAR FILTERS =====
    const clearFiltersBtn = document.getElementById('clearFiltersBtn');
    if (clearFiltersBtn) {
        clearFiltersBtn.addEventListener('click', function() {
            document.getElementById('searchRewards').value = '';
            document.getElementById('filterDepartment').value = '';
            document.getElementById('filterStatus').value = '';
            document.getElementById('filterPoints').value = '';
            
            // Show all rows
            document.querySelectorAll('#rewardsTableBody tr').forEach(row => {
                row.style.display = '';
            });
        });
    }

    // ===== REDEMPTION CHART =====
    const redemptionCtx = document.getElementById('redemptionChart');
    if (redemptionCtx) {
        // Get reward data from the page - use actual reward names
        const rewardRows = document.querySelectorAll('#rewardsTableBody tr[data-reward-id]');
        const datasets = [];
        const colors = [
            { border: '#10b981', bg: 'rgba(16, 185, 129, 0.1)' },
            { border: '#3b82f6', bg: 'rgba(59, 130, 246, 0.1)' },
            { border: '#f59e0b', bg: 'rgba(245, 158, 11, 0.1)' },
            { border: '#8b5cf6', bg: 'rgba(139, 92, 246, 0.1)' },
            { border: '#ef4444', bg: 'rgba(239, 68, 68, 0.1)' }
        ];

        rewardRows.forEach((row, index) => {
            if (index < 5) { // Limit to top 5 rewards
                const name = row.getAttribute('data-name');
                const color = colors[index % colors.length];
                datasets.push({
                    label: name,
                    data: [Math.floor(Math.random() * 20) + 5, 
                           Math.floor(Math.random() * 20) + 10, 
                           Math.floor(Math.random() * 20) + 8, 
                           Math.floor(Math.random() * 20) + 15, 
                           Math.floor(Math.random() * 20) + 12, 
                           Math.floor(Math.random() * 20) + 20],
                    borderColor: color.border,
                    backgroundColor: color.bg,
                    tension: 0.4
                });
            }
        });

        new Chart(redemptionCtx.getContext('2d'), {
            type: 'line',
            data: {
                labels: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'],
                datasets: datasets
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'bottom'
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true
                    }
                }
            }
        });
    }
});

// ===== MODAL FUNCTIONS =====

function initializeModals() {
    // Initialize Bootstrap modals
    const editModalEl = document.getElementById('editRewardModal');
    const restockModalEl = document.getElementById('restockModal');
    const deleteModalEl = document.getElementById('deleteModal');
    
    if (editModalEl) editModal = new bootstrap.Modal(editModalEl);
    if (restockModalEl) restockModal = new bootstrap.Modal(restockModalEl);
    if (deleteModalEl) deleteModal = new bootstrap.Modal(deleteModalEl);
}

function showEditModal(reward) {
    // Populate form fields
    document.getElementById('editRewardId').value = reward.id;
    document.getElementById('editRewardName').value = reward.name;
    document.getElementById('editRewardDepartment').value = reward.department;
    document.getElementById('editRewardPoints').value = reward.cost;
    document.getElementById('editRewardStock').value = reward.stock;
    
    // Show the modal
    editModal.show();
}

function showRestockModal(rewardId, rewardName) {
    document.getElementById('restockRewardId').value = rewardId;
    document.getElementById('restockRewardName').textContent = rewardName;
    document.getElementById('restockQuantity').value = '';
    restockModal.show();
}

function showDeleteModal(rewardId, rewardName) {
    document.getElementById('deleteRewardId').value = rewardId;
    document.getElementById('deleteRewardName').textContent = rewardName;
    deleteModal.show();
}

// Edit form submission
document.addEventListener('DOMContentLoaded', function() {
    const editForm = document.getElementById('editRewardForm');
    if (editForm) {
        editForm.addEventListener('submit', async function(e) {
            e.preventDefault();
            
            const rewardId = document.getElementById('editRewardId').value;
            const data = {
                name: document.getElementById('editRewardName').value.trim(),
                department: document.getElementById('editRewardDepartment').value,
                cost: parseInt(document.getElementById('editRewardPoints').value),
                stock: parseInt(document.getElementById('editRewardStock').value)
            };

            try {
                const response = await fetch(`/api/rewards/edit/${rewardId}`, {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify(data)
                });

                const result = await response.json();
                
                if (result.success) {
                    alert('Reward updated successfully!');
                    editModal.hide();
                    location.reload();
                } else {
                    alert('Error: ' + result.message);
                }
            } catch (error) {
                alert('Error updating reward: ' + error.message);
            }
        });
    }

    // Restock form submission
    const restockForm = document.getElementById('restockForm');
    if (restockForm) {
        restockForm.addEventListener('submit', async function(e) {
            e.preventDefault();
            
            const rewardId = document.getElementById('restockRewardId').value;
            const quantity = parseInt(document.getElementById('restockQuantity').value);

            try {
                const response = await fetch(`/api/rewards/restock/${rewardId}`, {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({ quantity: quantity })
                });

                const result = await response.json();
                
                if (result.success) {
                    alert('Reward restocked successfully!');
                    restockModal.hide();
                    location.reload();
                } else {
                    alert('Error: ' + result.message);
                }
            } catch (error) {
                alert('Error restocking reward: ' + error.message);
            }
        });
    }

    // Delete confirmation
    const confirmDeleteBtn = document.getElementById('confirmDeleteBtn');
    if (confirmDeleteBtn) {
        confirmDeleteBtn.addEventListener('click', async function() {
            const rewardId = document.getElementById('deleteRewardId').value;

            try {
                const response = await fetch(`/api/rewards/delete/${rewardId}`, {
                    method: 'POST'
                });

                const result = await response.json();
                
                if (result.success) {
                    alert('Reward deleted successfully!');
                    deleteModal.hide();
                    location.reload();
                } else {
                    alert('Error: ' + result.message);
                }
            } catch (error) {
                alert('Error deleting reward: ' + error.message);
            }
        });
    }
});
