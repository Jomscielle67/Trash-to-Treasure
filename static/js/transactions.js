/**
 * Transactions Management JavaScript
 * Handles filtering, verification, rejection, and modal functionality
 */

document.addEventListener('DOMContentLoaded', function() {
    // Reinitialize Lucide icons
    setTimeout(() => {
        lucide.createIcons();
    }, 100);

    // ===== SEARCH FUNCTIONALITY =====
    const searchInput = document.getElementById('searchTransactions');
    if (searchInput) {
        searchInput.addEventListener('input', function() {
            applyFilters();
        });
    }

    // ===== FILTER FUNCTIONALITY =====
    function applyFilters() {
        const searchTerm = document.getElementById('searchTransactions').value.toLowerCase();
        const typeFilter = document.getElementById('filterType').value.toLowerCase();
        const departmentFilter = document.getElementById('filterDepartment').value.toLowerCase();
        const statusFilter = document.getElementById('filterStatus').value.toLowerCase();
        const dateFilter = document.getElementById('filterDate').value;
        
        const rows = document.querySelectorAll('#transactionsTableBody tr[data-transaction-id]');
        
        rows.forEach(row => {
            let show = true;
            const rowText = row.textContent.toLowerCase();
            const type = row.getAttribute('data-type');
            const department = row.getAttribute('data-department').toLowerCase();
            const status = row.getAttribute('data-status');
            const date = row.getAttribute('data-date');
            
            // Search filter
            if (searchTerm && !rowText.includes(searchTerm)) {
                show = false;
            }
            
            // Type filter
            if (typeFilter && type !== typeFilter) {
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
            
            // Date filter
            if (dateFilter) {
                const today = new Date().toISOString().split('T')[0];
                const weekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString().split('T')[0];
                const monthAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0];
                
                if (dateFilter === 'today' && date !== today) {
                    show = false;
                } else if (dateFilter === 'week' && date < weekAgo) {
                    show = false;
                } else if (dateFilter === 'month' && date < monthAgo) {
                    show = false;
                }
            }
            
            row.style.display = show ? '' : 'none';
        });
    }

    // Attach filter event listeners
    document.getElementById('filterType').addEventListener('change', applyFilters);
    document.getElementById('filterDepartment').addEventListener('change', applyFilters);
    document.getElementById('filterStatus').addEventListener('change', applyFilters);
    document.getElementById('filterDate').addEventListener('change', applyFilters);

    // ===== CLEAR FILTERS =====
    document.querySelector('.btn-outline-secondary').addEventListener('click', function() {
        document.getElementById('searchTransactions').value = '';
        document.getElementById('filterType').value = '';
        document.getElementById('filterDepartment').value = '';
        document.getElementById('filterStatus').value = '';
        document.getElementById('filterDate').value = '';
        
        // Show all rows
        document.querySelectorAll('#transactionsTableBody tr').forEach(row => {
            row.style.display = '';
        });
    });

    // ===== QUICK FILTER BUTTONS =====
    document.querySelectorAll('.btn-group .btn').forEach(btn => {
        btn.addEventListener('click', function() {
            // Remove active class from all buttons
            document.querySelectorAll('.btn-group .btn').forEach(b => b.classList.remove('active'));
            // Add active class to clicked button
            this.classList.add('active');
            
            const filter = this.textContent.toLowerCase().trim();
            const rows = document.querySelectorAll('#transactionsTableBody tr[data-transaction-id]');
            
            rows.forEach(row => {
                const status = row.getAttribute('data-status');
                const date = row.getAttribute('data-date');
                const today = new Date().toISOString().split('T')[0];
                
                if (filter === 'all') {
                    row.style.display = '';
                } else if (filter === 'pending') {
                    row.style.display = status === 'pending' ? '' : 'none';
                } else if (filter === 'today') {
                    row.style.display = date === today ? '' : 'none';
                }
            });
        });
    });

    // ===== VIEW PROOF MODAL =====
    document.querySelectorAll('.view-proof-btn').forEach(btn => {
        btn.addEventListener('click', async function() {
            const transactionId = this.getAttribute('data-transaction-id');
            
            try {
                const response = await fetch(`/api/transactions/get/${transactionId}`);
                const result = await response.json();
                
                if (result.success) {
                    const transaction = result.transaction;
                    
                    // Populate modal with transaction details
                    document.getElementById('proofTransactionId').textContent = transaction.id.substring(0, 8).toUpperCase();
                    document.getElementById('proofType').textContent = transaction.type === 'deposit' ? 'Deposit' : 'Redemption';
                    document.getElementById('proofPoints').textContent = transaction.points;
                    document.getElementById('proofDate').textContent = transaction.date;
                    document.getElementById('proofStatus').textContent = transaction.status.charAt(0).toUpperCase() + transaction.status.slice(1);
                    document.getElementById('proofUser').textContent = transaction.user_name;
                    document.getElementById('proofDepartment').textContent = transaction.department;
                    
                    if (transaction.reward_name) {
                        document.getElementById('proofReward').textContent = transaction.reward_name;
                        document.getElementById('proofReward').parentElement.style.display = '';
                    } else {
                        document.getElementById('proofReward').parentElement.style.display = 'none';
                    }
                    
                    if (transaction.ticket_code && transaction.ticket_code !== 'N/A') {
                        document.getElementById('proofTicket').textContent = transaction.ticket_code;
                        document.getElementById('proofTicket').parentElement.style.display = '';
                    } else {
                        document.getElementById('proofTicket').parentElement.style.display = 'none';
                    }
                    
                    // Store transaction ID for verify/reject buttons
                    document.getElementById('proofModal').setAttribute('data-transaction-id', transaction.id);
                    
                    // Show/hide action buttons based on status
                    const modalVerifyBtn = document.querySelector('#proofModal .btn-success');
                    const modalRejectBtn = document.querySelector('#proofModal .btn-danger');
                    if (transaction.status === 'pending') {
                        if (modalVerifyBtn) modalVerifyBtn.style.display = '';
                        if (modalRejectBtn) modalRejectBtn.style.display = '';
                    } else {
                        if (modalVerifyBtn) modalVerifyBtn.style.display = 'none';
                        if (modalRejectBtn) modalRejectBtn.style.display = 'none';
                    }
                } else {
                    alert('Error loading transaction details: ' + result.message);
                }
            } catch (error) {
                console.error('Error:', error);
                alert('Error loading transaction details');
            }
        });
    });

    // ===== VERIFY TRANSACTION =====
    document.querySelectorAll('.verify-btn').forEach(btn => {
        btn.addEventListener('click', async function() {
            const transactionId = this.getAttribute('data-transaction-id');
            
            if (confirm('Mark this transaction as verified?')) {
                try {
                    const response = await fetch(`/api/transactions/verify/${transactionId}`, {
                        method: 'POST'
                    });
                    
                    const result = await response.json();
                    
                    if (result.success) {
                        alert('Transaction verified successfully!');
                        location.reload();
                    } else {
                        alert('Error: ' + result.message);
                    }
                } catch (error) {
                    console.error('Error:', error);
                    alert('Error verifying transaction');
                }
            }
        });
    });

    // ===== REJECT TRANSACTION =====
    document.querySelectorAll('.reject-btn').forEach(btn => {
        btn.addEventListener('click', async function() {
            const transactionId = this.getAttribute('data-transaction-id');
            
            if (confirm('Reject this transaction? This action cannot be undone.')) {
                try {
                    const response = await fetch(`/api/transactions/reject/${transactionId}`, {
                        method: 'POST'
                    });
                    
                    const result = await response.json();
                    
                    if (result.success) {
                        alert('Transaction rejected successfully!');
                        location.reload();
                    } else {
                        alert('Error: ' + result.message);
                    }
                } catch (error) {
                    console.error('Error:', error);
                    alert('Error rejecting transaction');
                }
            }
        });
    });

    // ===== MODAL VERIFY/REJECT BUTTONS =====
    const modalVerifyBtn = document.querySelector('#proofModal .btn-success');
    const modalRejectBtn = document.querySelector('#proofModal .btn-danger');
    
    if (modalVerifyBtn) {
        modalVerifyBtn.addEventListener('click', async function() {
            const transactionId = document.getElementById('proofModal').getAttribute('data-transaction-id');
            
            if (confirm('Verify this transaction?')) {
                try {
                    const response = await fetch(`/api/transactions/verify/${transactionId}`, {
                        method: 'POST'
                    });
                    
                    const result = await response.json();
                    
                    if (result.success) {
                        alert('Transaction verified successfully!');
                        location.reload();
                    } else {
                        alert('Error: ' + result.message);
                    }
                } catch (error) {
                    console.error('Error:', error);
                    alert('Error verifying transaction');
                }
            }
        });
    }
    
    if (modalRejectBtn) {
        modalRejectBtn.addEventListener('click', async function() {
            const transactionId = document.getElementById('proofModal').getAttribute('data-transaction-id');
            
            if (confirm('Reject this transaction? This action cannot be undone.')) {
                try {
                    const response = await fetch(`/api/transactions/reject/${transactionId}`, {
                        method: 'POST'
                    });
                    
                    const result = await response.json();
                    
                    if (result.success) {
                        alert('Transaction rejected successfully!');
                        location.reload();
                    } else {
                        alert('Error: ' + result.message);
                    }
                } catch (error) {
                    console.error('Error:', error);
                    alert('Error rejecting transaction');
                }
            }
        });
    }

    // ===== EXPORT TRANSACTIONS =====
    const exportBtn = document.querySelector('.btn-primary[title*="Export"], .btn-primary');
    if (exportBtn && exportBtn.textContent.includes('Export')) {
        exportBtn.addEventListener('click', function() {
            alert('Export functionality coming soon!');
            // TODO: Implement CSV/Excel export
        });
    }

    // ===== REFRESH PAGE =====
    const refreshBtn = document.querySelector('.btn-outline-primary[title*="Refresh"], .btn-outline-primary');
    if (refreshBtn && refreshBtn.textContent.includes('Refresh')) {
        refreshBtn.addEventListener('click', function() {
            location.reload();
        });
    }
});
