// Department CRUD Operations

// Create toast container if it doesn't exist
function createToastContainer() {
    if (!document.getElementById('toastContainer')) {
        const container = document.createElement('div');
        container.id = 'toastContainer';
        container.className = 'toast-container position-fixed top-0 end-0 p-3';
        container.style.zIndex = '9999';
        document.body.appendChild(container);
    }
}

// Show toast notification
function showToast(message, type = 'info') {
    createToastContainer();
    
    const toastId = 'toast-' + Date.now();
    const bgClass = type === 'success' ? 'bg-success' : type === 'error' ? 'bg-danger' : 'bg-primary';
    const icon = type === 'success' ? '✓' : type === 'error' ? '✗' : 'ℹ';
    
    const toastHTML = `
        <div id="${toastId}" class="toast align-items-center text-white ${bgClass} border-0" role="alert" aria-live="assertive" aria-atomic="true">
            <div class="d-flex">
                <div class="toast-body">
                    <strong>${icon}</strong> ${message}
                </div>
                <button type="button" class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast" aria-label="Close"></button>
            </div>
        </div>
    `;
    
    document.getElementById('toastContainer').insertAdjacentHTML('beforeend', toastHTML);
    
    const toastElement = document.getElementById(toastId);
    const toast = new bootstrap.Toast(toastElement, {
        autohide: true,
        delay: type === 'success' ? 3000 : 5000
    });
    
    toast.show();
    
    // Remove toast element after it's hidden
    toastElement.addEventListener('hidden.bs.toast', function() {
        toastElement.remove();
    });
}

// Show loading toast
function showLoading(message = 'Processing...') {
    showToast(message, 'info');
}

// Show success message
function showSuccess(message) {
    showToast(message, 'success');
}

// Show error message
function showError(message) {
    showToast(message, 'error');
}

// Initialize all department functionality when page loads
document.addEventListener('DOMContentLoaded', function() {
    console.log('Departments.js loaded successfully');
    
    // ===== ADD DEPARTMENT =====
    const addForm = document.getElementById('addDepartmentForm');
    if (addForm) {
        addForm.addEventListener('submit', async function(e) {
            e.preventDefault();
            console.log('Add department form submitted');
            
            const formData = {
                name: document.getElementById('addDeptName').value,
                location: document.getElementById('addDeptLocation').value,
                icon: document.getElementById('addDeptIcon').value,
                description: document.getElementById('addDeptDescription').value,
                bottle_rate: parseFloat(document.getElementById('addDeptBottleRate').value),
                order: parseInt(document.getElementById('addDeptOrder').value),
                status: document.getElementById('addDeptStatus').value
            };
            
            console.log('Form data:', formData);
            
            // Validate name
            if (!formData.name || formData.name.trim().length === 0) {
                showError('Department name is required');
                return;
            }
            
            showLoading('Adding department...');
            
            try {
                console.log('Sending request to /api/departments/add...');
                const response = await fetch('/api/departments/add', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify(formData)
                });
                
                console.log('Response status:', response.status);
                console.log('Response headers:', response.headers);
                
                // Always try to parse as JSON first (even for errors)
                let data;
                try {
                    data = await response.json();
                    console.log('API response:', data);
                } catch (e) {
                    console.error('Failed to parse JSON:', e);
                    const errorText = await response.text();
                    console.error('Response text:', errorText);
                    showError(`Server error: ${response.status} - Could not parse response`);
                    return;
                }
                
                // Check if request was successful
                if (!response.ok) {
                    console.error('Request failed with status:', response.status);
                    console.error('Error message:', data.message);
                    showError(data.message || `Server error: ${response.status}`);
                    return;
                }
                
                // Response was OK (200)
                showSuccess('✓ Department added successfully!');
                
                // Close modal after a short delay
                setTimeout(() => {
                    const modal = bootstrap.Modal.getInstance(document.getElementById('addDepartmentModal'));
                    if (modal) modal.hide();
                    
                    // Reset form
                    addForm.reset();
                    
                    // Reload page
                    location.reload();
                }, 1500);
            } catch (error) {
                console.error('Error adding department:', error);
                showError('Network error: ' + error.message);
            }
        });
    } else {
        console.error('Add department form not found!');
    }
    
    // ===== EDIT DEPARTMENT =====
    document.querySelectorAll('.edit-dept-btn').forEach(btn => {
        btn.addEventListener('click', async function() {
            const deptId = this.getAttribute('data-dept-id');
            const deptIndex = parseInt(this.getAttribute('data-dept-index'));
            
            console.log('Edit button clicked for dept:', deptId, 'index:', deptIndex);
            
            // Get department data from the page
            const departmentsDataEl = document.getElementById('departmentsData');
            if (!departmentsDataEl) {
                showError('Department data not found');
                return;
            }
            
            const departments = JSON.parse(departmentsDataEl.textContent);
            const dept = departments[deptIndex];
            
            if (!dept) {
                showError('Department not found');
                return;
            }
            
            // Populate form fields
            document.getElementById('editDeptId').value = deptId;
            document.getElementById('editDeptName').value = dept.name;
            document.getElementById('editDeptLocation').value = dept.location || '';
            document.getElementById('editDeptIcon').value = dept.icon || '🏫';
            document.getElementById('editDeptDescription').value = dept.description || '';
            document.getElementById('editDeptBottleRate').value = dept.bottle_rate || 1;
            document.getElementById('editDeptOrder').value = dept.order || 0;
            document.getElementById('editDeptStatus').value = dept.status || 'active';
            
            // Show modal
            const modal = new bootstrap.Modal(document.getElementById('editDepartmentModal'));
            modal.show();
            
            // Reinitialize Lucide icons
            setTimeout(() => lucide.createIcons(), 100);
        });
    });
    
    // Edit Form Submission
    const editForm = document.getElementById('editDepartmentForm');
    if (editForm) {
        editForm.addEventListener('submit', async function(e) {
            e.preventDefault();
            
            const deptId = document.getElementById('editDeptId').value;
            const formData = {
                name: document.getElementById('editDeptName').value,
                location: document.getElementById('editDeptLocation').value,
                icon: document.getElementById('editDeptIcon').value,
                description: document.getElementById('editDeptDescription').value,
                bottle_rate: parseFloat(document.getElementById('editDeptBottleRate').value),
                order: parseInt(document.getElementById('editDeptOrder').value),
                status: document.getElementById('editDeptStatus').value
            };
            
            // Validate name
            if (!formData.name || formData.name.trim().length === 0) {
                showError('Department name is required');
                return;
            }
            
            showLoading('Updating department...');
            
            try {
                const response = await fetch(`/api/departments/edit/${deptId}`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify(formData)
                });
                
                const data = await response.json();
                
                if (data.success) {
                    showSuccess('Department updated successfully!');
                    
                    // Close modal
                    const modal = bootstrap.Modal.getInstance(document.getElementById('editDepartmentModal'));
                    if (modal) modal.hide();
                    
                    // Reload page after short delay
                    setTimeout(() => {
                        location.reload();
                    }, 1500);
                } else {
                    showError(data.message || 'Failed to update department');
                }
            } catch (error) {
                console.error('Error updating department:', error);
                showError('An error occurred while updating the department');
            }
        });
    }
    
    // ===== DELETE DEPARTMENT =====
    document.querySelectorAll('.delete-dept-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            const deptId = this.getAttribute('data-dept-id');
            const deptName = this.getAttribute('data-dept-name');
            
            // Populate delete modal
            document.getElementById('deleteDeptId').value = deptId;
            document.getElementById('deleteDeptName').textContent = deptName;
            
            // Show modal
            const modal = new bootstrap.Modal(document.getElementById('deleteDepartmentModal'));
            modal.show();
            
            // Reinitialize Lucide icons
            setTimeout(() => lucide.createIcons(), 100);
        });
    });
    
    // Confirm Delete Button
    const confirmDeleteBtn = document.getElementById('confirmDeleteBtn');
    if (confirmDeleteBtn) {
        confirmDeleteBtn.addEventListener('click', async function() {
            const deptId = document.getElementById('deleteDeptId').value;
            
            showLoading('Deleting department...');
            
            try {
                const response = await fetch(`/api/departments/delete/${deptId}`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    }
                });
                
                const data = await response.json();
                
                if (data.success) {
                    showSuccess('Department deleted successfully!');
                    
                    // Close modal
                    const modal = bootstrap.Modal.getInstance(document.getElementById('deleteDepartmentModal'));
                    if (modal) modal.hide();
                    
                    // Reload page after short delay
                    setTimeout(() => {
                        location.reload();
                    }, 1500);
                } else {
                    showError(data.message || 'Failed to delete department');
                }
            } catch (error) {
                console.error('Error deleting department:', error);
                showError('An error occurred while deleting the department');
            }
        });
    }
    
    // ===== REINITIALIZE ICONS ON MODAL SHOW =====
    document.querySelectorAll('.modal').forEach(modal => {
        modal.addEventListener('shown.bs.modal', function() {
            lucide.createIcons();
        });
    });
});
