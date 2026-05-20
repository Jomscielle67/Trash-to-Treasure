from flask import Flask, render_template, request, redirect, url_for, flash, session, g, jsonify
from services.firebase_service import db
import os
from models.notification_model import Notification
from models.student_model import Student
from models.admin_model import Admin
from models.transaction import Transaction
from models.rewards import Reward
from models.department_model import Department
from models.machine_model import Machine
from models.super_user_model import SuperUser
from datetime import datetime, timedelta
import secrets
from functools import wraps
import traceback
import io

app = Flask(__name__)
# Use a fixed SECRET_KEY env var so sessions survive container restarts and
# are consistent across Cloud Run instances.  Fall back to a generated key for
# local dev only (sessions won't persist across restarts in that case).
app.secret_key = os.environ.get('SECRET_KEY') or secrets.token_hex(32)

# Session configuration
app.config['PERMANENT_SESSION_LIFETIME'] = timedelta(days=30)  # 30 days persistent session
app.config['SESSION_PERMANENT'] = True
app.config['MAX_CONTENT_LENGTH'] = 10 * 1024 * 1024  # 10 MB max upload

@app.context_processor
def inject_unread_messages():
    """Inject unread contact-message count so sidebar badge works on every page."""
    try:
        if session.get('user_id'):
            docs = db.collection('contact_messages').where('status', '==', 'new').stream()
            count = sum(1 for _ in docs)
            return {'unread_messages_count': count}
    except Exception:
        pass
    return {'unread_messages_count': 0}


def _notify_admins(title, body, notif_type='system', priority='normal', extra_data=None):
    """Silently create a broadcast notification visible to all admin users in the panel."""
    try:
        n = Notification(
            user_id='admin',
            user_type='admin',
            title=title,
            body=body,
            notification_type=notif_type,
            priority=priority,
            data=extra_data or {},
            created_by=session.get('user_email', 'system')
        )
        n.save()
    except Exception as e:
        print(f"[notify_admins] {e}")


def _parse_ts(val):
    """Return naive UTC datetime from a Firestore timestamp or ISO string."""
    if val is None:
        return None
    s = val.isoformat() if hasattr(val, 'isoformat') else str(val)
    s = s.replace('Z', '').split('+')[0].split('.')[0]
    try:
        return datetime.fromisoformat(s)
    except Exception:
        return None


def login_required(f):
    """Decorator to require login for protected routes - supports both SuperUser and Admin."""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if not session.get('user_id') or not session.get('session_token'):
            flash('Please log in to access this page.', 'error')
            return redirect(url_for('home'))
        
        # Get user type from session
        user_type = session.get('user_type', 'super_user')
        
        # Verify user based on type
        if user_type == 'super_user':
            user = SuperUser.get_by_id(session['user_id'])
            if not user or session['session_token'] not in user.session_tokens:
                session.clear()
                flash('Your session has expired. Please log in again.', 'error')
                return redirect(url_for('home'))
            
            # Check if account is still active and not locked
            if user.status != 'active' or user.is_account_locked():
                session.clear()
                flash('Your account has been suspended or locked. Please contact an administrator.', 'error')
                return redirect(url_for('home'))
        else:  # admin
            user = Admin.get_admin_by_id(session['user_id'])
            if not user:
                session.clear()
                flash('Your session has expired. Please log in again.', 'error')
                return redirect(url_for('home'))
            
            # Check if admin account is still active
            if user.status != 'active':
                session.clear()
                flash('Your admin account is not active. Please contact the system administrator.', 'error')
                return redirect(url_for('home'))
        
        # Refresh session lifetime on each request for persistent login
        remember_me = session.get('remember_me', False)
        if remember_me:
            session.permanent = True  # Keep persistent session active
        
        # Store user in g for use in templates
        g.current_user = user
        g.user_type = user_type
        return f(*args, **kwargs)
    
    return decorated_function

@app.before_request
def load_logged_in_user():
    """Load the logged-in user before each request - supports both SuperUser and Admin."""
    user_id = session.get('user_id')
    session_token = session.get('session_token')
    user_type = session.get('user_type', 'super_user')
    
    if user_id and session_token:
        if user_type == 'super_user':
            user = SuperUser.get_by_id(user_id)
            if user and session_token in user.session_tokens:
                g.current_user = user
                g.user_type = user_type
            else:
                g.current_user = None
                g.user_type = None
        else:  # admin
            user = Admin.get_admin_by_id(user_id)
            if user:
                g.current_user = user
                g.user_type = user_type
            else:
                g.current_user = None
                g.user_type = None
    else:
        g.current_user = None
        g.user_type = None

@app.route('/home', methods=['GET', 'POST'])
def home():
    """Landing page and login handler."""
    # Redirect already-logged-in users straight to the dashboard
    if session.get('user_id') and session.get('session_token'):
        return redirect(url_for('dashboard'))
    if request.method == 'POST':
        email = request.form.get('email', '').strip().lower()
        password = request.form.get('password', '')
        remember_me = request.form.get('remember_me') == 'on'
        
        if not email or not password:
            flash('Please provide both email and password.', 'error')
            return render_template('login.html')
        
        # Get client IP address
        client_ip = request.environ.get('HTTP_X_FORWARDED_FOR', request.environ.get('REMOTE_ADDR', ''))
        
        # First, try to authenticate as SuperUser
        user = SuperUser.authenticate(email, password, client_ip)
        user_type = 'super_user'
        
        # If SuperUser authentication fails, check Admin collection
        if not user:
            admin = Admin.get_admin_by_email(email)
            if admin and admin.status == 'active':
                # Check if admin has a password stored (added via web interface)
                admin_data = db.collection('admins').document(admin.id).get().to_dict()
                stored_password = admin_data.get('password', '')
                
                # Simple password check (Note: In production, use hashed passwords!)
                if stored_password == password:
                    user = admin
                    user_type = 'admin'
                    # Update admin login stats
                    admin.total_logins = (admin.total_logins or 0) + 1
                    admin.last_login_at = datetime.now()
                    admin.save()
        
        if user:
            # Generate session token (for SuperUser) or create a simple one (for Admin)
            if user_type == 'super_user':
                session_token = user.generate_session_token()
            else:
                # For admin, create a simple session token
                import secrets
                session_token = secrets.token_urlsafe(32)
            
            # Always create a persistent session (survives browser close)
            session.permanent = True  # 30 days as configured
                
            session['user_id'] = user.id
            session['session_token'] = session_token
            session['user_email'] = user.email
            session['user_type'] = user_type
            
            # Set user name based on account type
            if user_type == 'super_user':
                session['user_name'] = user.full_name
                user_display_name = user.full_name
            else:
                session['user_name'] = user.name
                user_display_name = user.name
            
            session['login_time'] = datetime.now().isoformat()
            session['remember_me'] = remember_me
            
            if remember_me:
                flash(f'Welcome back, {user_display_name}! You\'ll stay signed in for 30 days.', 'success')
            else:
                flash(f'Welcome back, {user_display_name}!', 'success')
            return redirect(url_for('dashboard'))
        else:
            # Check if user exists but account is locked/inactive
            existing_super_user = SuperUser.get_by_email(email)
            if existing_super_user and existing_super_user.is_account_locked():
                flash('Your account has been temporarily locked due to multiple failed login attempts. Please try again later.', 'error')
            else:
                existing_admin = Admin.get_admin_by_email(email)
                if existing_admin and existing_admin.status != 'active':
                    flash(f'Your admin account is currently {existing_admin.status}. Please contact the system administrator.', 'error')
                else:
                    flash('Invalid email or password. Please try again.', 'error')
    
    return render_template('login.html')

@app.route('/login')
def login_redirect():
    """Backward-compat redirect: /login -> /home."""
    return redirect(url_for('home'))

@app.route('/register', methods=['GET', 'POST'])
def register():
    """Handle user registration."""
    if request.method == 'POST':
        full_name = request.form.get('full_name', '').strip()
        email = request.form.get('email', '').strip().lower()
        department = request.form.get('department', '').strip()
        password = request.form.get('password', '')
        confirm_password = request.form.get('confirm_password', '')
        
        # Validation
        errors = []
        
        if not full_name:
            errors.append('Full name is required.')
        
        if not email:
            errors.append('Email address is required.')
        elif not SuperUser.validate_email(email):
            errors.append('Please provide a valid email address.')
        
        if not department:
            errors.append('Department is required.')
        
        if not password:
            errors.append('Password is required.')
        elif password != confirm_password:
            errors.append('Passwords do not match.')
        else:
            # Validate password strength
            password_validation = SuperUser.validate_password(password)
            if not password_validation['is_valid']:
                errors.extend(password_validation['errors'])
        
        # Check if email already exists
        if SuperUser.get_by_email(email):
            errors.append('An account with this email address already exists.')
        
        # If there are errors, show them
        if errors:
            for error in errors:
                flash(error, 'error')
            return render_template('register.html')
        
        # Create the super user account
        super_user = SuperUser.create_super_user(
            full_name=full_name,
            email=email,
            password=password,
            department=department
        )
        
        if super_user:
            _notify_admins(
                '👤 New User Registered',
                f'{full_name} ({email}) just created an account',
                notif_type='system', priority='normal'
            )
            flash('Account created successfully! You can now log in.', 'success')
            return redirect(url_for('home'))
        else:
            flash('Failed to create account. Please try again.', 'error')
    
    return render_template('register.html')

@app.route('/logout')
def logout():
    """Handle user logout - supports both SuperUser and Admin."""
    if session.get('user_id') and session.get('session_token'):
        user_type = session.get('user_type', 'super_user')
        
        # Invalidate the session token (only for SuperUser, Admin uses simple token)
        if user_type == 'super_user':
            user = SuperUser.get_by_id(session['user_id'])
            if user:
                user.invalidate_session_token(session['session_token'])
    
    # Clear the session
    session.clear()
    flash('You have been logged out successfully.', 'success')
    return redirect(url_for('home'))

@app.route('/')
@app.route('/dashboard')
@login_required
def dashboard():
    try:
        # Get real statistics from models
        student_stats = Student.get_student_statistics()
        transaction_stats = Transaction.get_transaction_statistics()
        department_stats = Department.get_department_statistics()
        machine_stats = Machine.get_machine_statistics()
        
        # Get recent transactions for activities
        recent_transactions_raw = Transaction.get_all_transactions(limit=5)
        recent_transactions = []
        
        for transaction in recent_transactions_raw:
            # Get student info
            student = Student.get_student_by_id(transaction.user_id)
            student_name = student.full_name if student else (transaction.student_name if hasattr(transaction, 'student_name') else 'Unknown Student')
            
            recent_transactions.append({
                'user': student_name,
                'type': transaction.type,
                'points': transaction.points,
                'bottles': getattr(transaction, 'bottles', 0),
                'reward_name': getattr(transaction, 'reward_name', ''),
                'timestamp': transaction.timestamp
            })
        
        # Get machine data
        machines = Machine.get_all_machines()
        machine_data = []
        for machine in machines:
            machine_data.append({
                'id': machine.machine_id,
                'location': machine.location,
                'status': machine.status,
                'bottles': machine.get_fill_percentage()
            })
        
        # Get top students (sorted by bottles this week)
        all_students = Student.get_all_students()
        top_students = sorted(all_students, key=lambda x: x.bottles, reverse=True)[:5]
        
        # Get department bottle data - use student_stats department_breakdown
        # This uses totalBottlesLifetime from all students grouped by department
        dept_breakdown = student_stats.get('department_breakdown', {})
        dept_data = {}
        
        # Extract bottle counts from department breakdown
        for dept_name, dept_info in dept_breakdown.items():
            if dept_name:  # Only include departments with names
                dept_data[dept_name] = dept_info.get('bottles', 0)
        
        # Fallback: if no department data, try manual aggregation
        if not dept_data:
            all_students = Student.get_all_students()
            for student in all_students:
                if student.department:
                    dept_data[student.department] = dept_data.get(student.department, 0) + student.total_bottles_lifetime
        
        # Get reward redemption data - use transaction_stats popular_rewards
        # This already calculates and sorts popular rewards
        popular_rewards = transaction_stats.get('popular_rewards', [])
        
        # Fallback: if no popular rewards from stats, try manual aggregation
        if not popular_rewards:
            reward_redemptions = {}
            all_rewards = Transaction.get_transactions_by_type('redeem', limit=100)
            for trans in all_rewards:
                if trans.reward_name:
                    reward_redemptions[trans.reward_name] = reward_redemptions.get(trans.reward_name, 0) + 1
            
            # Sort rewards by redemption count
            popular_rewards = sorted(reward_redemptions.items(), key=lambda x: x[1], reverse=True)[:5]
        
        # Compile dashboard statistics - using correct keys from model statistics
        stats = {
            'total_bottles': student_stats.get('total_bottles', 0),  # From Student.get_student_statistics()
            'total_points': student_stats.get('current_points', 0),  # Current points in circulation
            'active_users': student_stats.get('active_students', 0),  # Active status students
            'rewards_redeemed': transaction_stats.get('completed_redemptions', 0),  # Completed redemptions
            'machines_online': machine_stats.get('active_machines', 0),
            'total_machines': machine_stats.get('total_machines', 1)
        }

    except Exception as e:
        print(f"Error in dashboard route: {e}")
        import traceback
        traceback.print_exc()
        
        # Fallback to empty data if there's an error
        top_students = []
        dept_data = {}
        popular_rewards = []
        stats = {
            'total_bottles': 0,
            'total_points': 0,
            'active_users': 0,
            'rewards_redeemed': 0,
            'machines_online': 0,
            'total_machines': 1
        }
        recent_transactions = []
        machine_data = []
        student_stats = {}

    return render_template('dashboard.html', 
                         students=top_students, 
                         student_data=student_stats,
                         stats=stats, 
                         recent_transactions=recent_transactions,
                         machines=machine_data,
                         dept_data=dept_data,
                         popular_rewards=popular_rewards)

@app.route('/departments')
@login_required
def departments():
    try:
        # Get all departments with real data
        all_departments = Department.get_all_departments()
        
        # Get student statistics for efficient department breakdown
        student_stats = Student.get_student_statistics()
        dept_breakdown = student_stats.get('department_breakdown', {})
        
        # Format departments for template
        departments_data = []
        for dept in all_departments:
            # Get stats from breakdown (uses totalBottlesLifetime)
            dept_stats = dept_breakdown.get(dept.name, {})
            total_students = dept_stats.get('count', 0)
            total_bottles = dept_stats.get('bottles', 0)  # This is totalBottlesLifetime
            total_points = dept_stats.get('points', 0)    # This is current points
            
            # Only include departments with students (optional: remove this if you want to show all)
            if total_students == 0:
                continue
            
            # Get students in this department to find top recycler
            dept_students = Student.get_students_by_department(dept.name)
            
            # Find top recycler by totalBottlesLifetime
            top_recycler = 'No students'
            top_recycler_bottles = 0
            if dept_students:
                top_student = max(dept_students, key=lambda x: x.total_bottles_lifetime)
                top_recycler = top_student.full_name
                top_recycler_bottles = top_student.total_bottles_lifetime
            
            # Calculate average bottles per student (lifetime bottles)
            avg_bottles = total_bottles / total_students if total_students > 0 else 0
            
            # Get department admin info
            dept_admin = None
            if dept.admin_id:
                dept_admin = Admin.get_admin_by_id(dept.admin_id)
            
            # Prepare student list for modal
            students_list = []
            for student in sorted(dept_students, key=lambda x: x.total_bottles_lifetime, reverse=True):
                students_list.append({
                    'id': student.id,
                    'name': student.full_name,
                    'student_id': student.student_id,
                    'email': student.email,
                    'bottles': student.total_bottles_lifetime,
                    'points': student.points,
                    'status': student.status,
                    'year_level': student.year_level,
                    'course': student.course
                })
            
            departments_data.append({
                'id': dept.id,
                'name': dept.name,
                'students': total_students,
                'bottles': total_bottles,
                'points': total_points,
                'top_recycler': top_recycler,
                'top_recycler_bottles': top_recycler_bottles,
                'avg': round(avg_bottles, 2),
                'admin_id': dept.admin_id,
                'location': dept.location,
                'bottle_rate': dept.bottle_rate,
                'icon': dept.icon if hasattr(dept, 'icon') else '🏫',
                'description': dept.description if hasattr(dept, 'description') else '',
                'order': dept.order if hasattr(dept, 'order') else 0,
                'status': dept.status if hasattr(dept, 'status') else 'active',
                'admin': {
                    'name': dept_admin.name if dept_admin else 'Not Assigned',
                    'email': dept_admin.email if dept_admin else '',
                    'position': dept_admin.position if dept_admin else '',
                    'phone': dept_admin.phone_number if dept_admin else '',
                    'office': dept_admin.office_location if dept_admin else '',
                    'hours': dept_admin.office_hours if dept_admin else ''
                },
                'students_list': students_list
            })
        
        # Sort by points (highest first)
        departments_data.sort(key=lambda x: x['points'], reverse=True)
        
    except Exception as e:
        print(f"Error in departments route: {e}")
        import traceback
        traceback.print_exc()
        departments_data = []
    
    return render_template('departments.html', departments=departments_data)

# Department API Endpoints
@app.route('/api/departments/add', methods=['POST'])
@login_required
def api_add_department():
    """Add a new department"""
    try:
        data = request.get_json()
        print(f"[ADD DEPARTMENT] Received data: {data}")
        
        # Validate required fields
        if not data.get('name'):
            print("[ADD DEPARTMENT] Error: Department name is required")
            return jsonify({'success': False, 'message': 'Department name is required'}), 400
        
        # Create department object
        new_dept = Department(
            name=data['name'],
            location=data.get('location', ''),
            bottle_rate=float(data.get('bottle_rate', 1)),
            status=data.get('status', 'active'),
            icon=data.get('icon', '🏫'),
            description=data.get('description', ''),
            order=int(data.get('order', 0)),
            created_by=session.get('user_email', 'system')
        )
        print(f"[ADD DEPARTMENT] Created department object: {new_dept.name}")
        
        # Validate name uniqueness
        print("[ADD DEPARTMENT] Validating name uniqueness...")
        is_unique, message = new_dept.validate_name_unique()
        print(f"[ADD DEPARTMENT] Uniqueness check: {is_unique}, Message: {message}")
        if not is_unique:
            print(f"[ADD DEPARTMENT] Validation failed: {message}")
            return jsonify({'success': False, 'message': message}), 400
        
        # Save to Firebase
        print("[ADD DEPARTMENT] Saving to Firebase...")
        dept_id = new_dept.save()
        print(f"[ADD DEPARTMENT] Saved with ID: {dept_id}")
        
        if dept_id:
            print("[ADD DEPARTMENT] Success! Department added.")
            return jsonify({
                'success': True,
                'message': 'Department added successfully',
                'department': new_dept.to_dict()
            }), 200
        else:
            print("[ADD DEPARTMENT] Error: Failed to save department")
            return jsonify({'success': False, 'message': 'Failed to save department'}), 500
            
    except Exception as e:
        print(f"[ADD DEPARTMENT] Exception occurred: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': str(e)}), 500

@app.route('/api/departments/edit/<dept_id>', methods=['POST'])
@login_required
def api_edit_department(dept_id):
    """Edit an existing department"""
    try:
        data = request.get_json()
        
        # Get existing department
        dept = Department.get_department_by_id(dept_id)
        if not dept:
            return jsonify({'success': False, 'message': 'Department not found'}), 404
        
        # Update fields
        if 'name' in data:
            dept.name = data['name']
        if 'location' in data:
            dept.location = data['location']
        if 'bottle_rate' in data:
            dept.bottle_rate = float(data['bottle_rate'])
        if 'status' in data:
            dept.status = data['status']
        if 'icon' in data:
            dept.icon = data['icon']
        if 'description' in data:
            dept.description = data['description']
        if 'order' in data:
            dept.order = int(data['order'])
        
        # Validate name uniqueness (will exclude current dept)
        is_unique, message = dept.validate_name_unique()
        if not is_unique:
            return jsonify({'success': False, 'message': message}), 400
        
        # Save changes
        dept.save()
        
        return jsonify({
            'success': True,
            'message': 'Department updated successfully',
            'department': dept.to_dict()
        }), 200
            
    except Exception as e:
        print(f"Error editing department: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': str(e)}), 500

@app.route('/api/departments/delete/<dept_id>', methods=['POST'])
@login_required
def api_delete_department(dept_id):
    """Delete a department (with validation)"""
    try:
        # Get department
        dept = Department.get_department_by_id(dept_id)
        if not dept:
            return jsonify({'success': False, 'message': 'Department not found'}), 404
        
        # Check if department can be deleted
        can_delete, message = dept.can_be_deleted()
        if not can_delete:
            return jsonify({'success': False, 'message': message}), 400
        
        # Delete from Firebase
        success = dept.delete()
        
        if success:
            return jsonify({
                'success': True,
                'message': f'Department "{dept.name}" deleted successfully'
            }), 200
        else:
            return jsonify({'success': False, 'message': 'Failed to delete department'}), 500
            
    except Exception as e:
        print(f"Error deleting department: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': str(e)}), 500

@app.route('/api/departments/toggle-status/<dept_id>', methods=['POST'])
@login_required
def api_toggle_department_status(dept_id):
    """Toggle department active/inactive status"""
    try:
        # Get department
        dept = Department.get_department_by_id(dept_id)
        if not dept:
            return jsonify({'success': False, 'message': 'Department not found'}), 404
        
        # Toggle status
        new_status = 'inactive' if dept.status == 'active' else 'active'
        dept.update_status(new_status)
        
        return jsonify({
            'success': True,
            'message': f'Department {new_status}',
            'status': new_status,
            'department': dept.to_dict()
        }), 200
            
    except Exception as e:
        print(f"Error toggling department status: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': str(e)}), 500

@app.route('/api/departments/get/<dept_id>', methods=['GET'])
@login_required
def api_get_department(dept_id):
    """Get single department details"""
    try:
        # Get department
        dept = Department.get_department_by_id(dept_id)
        if not dept:
            return jsonify({'success': False, 'message': 'Department not found'}), 404
        
        # Get additional stats
        student_count = dept.get_student_count()
        
        dept_data = dept.to_dict()
        dept_data['student_count'] = student_count
        
        return jsonify({
            'success': True,
            'department': dept_data
        }), 200
            
    except Exception as e:
        print(f"Error getting department: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': str(e)}), 500

@app.route('/rewards')
@login_required
def rewards():
    try:
        # Get all rewards with real data
        all_rewards = Reward.get_all_rewards()
        reward_stats = Reward.get_reward_statistics()
        
        # Get department names from database (only active departments)
        department_names = sorted(Department.get_department_names(include_inactive=False))
        
        # Format rewards for template
        rewards_data = []
        for reward in all_rewards:
            # Determine actual status based on stock
            if reward.stock == 0:
                actual_status = 'out_of_stock'
            elif reward.status == 'active' or reward.status == 'ACTIVE':
                actual_status = 'active'
            else:
                actual_status = 'inactive'
            
            # Simple emoji mapping based on reward name
            emoji_map = {
                'coffee': '☕', 'shirt': '👕', 'notebook': '📓', 'water': '🍼',
                'lunch': '🍽️', 'pen': '✒️', 'art': '🎨', 'coat': '🥼',
                'bag': '🎒', 'book': '📚', 'mug': '☕', 'tumbler': '🥤',
                'card': '🎫', 'voucher': '🎟️', 'meal': '🍱', 'snack': '🍿'
            }
            
            # Find appropriate emoji
            reward_emoji = '🎁'  # default
            for key, emoji in emoji_map.items():
                if key.lower() in reward.name.lower():
                    reward_emoji = emoji
                    break
            
            rewards_data.append({
                'id': reward.id,
                'name': reward.name,
                'department': reward.department,
                'cost': reward.cost,  # Changed from 'points' to 'cost' to match template
                'stock': reward.stock,
                'created_by': reward.created_by or 'Admin',
                'status': actual_status,
                'image': reward_emoji,
                'created_at': reward.created_at
            })
        
        # Sort by created_at descending (newest first)
        rewards_data.sort(key=lambda x: x.get('created_at') or datetime.min, reverse=True)
        
        # Compile statistics
        stats = {
            'total_rewards': reward_stats.get('total_rewards', 0),
            'active_rewards': len([r for r in rewards_data if r['status'] == 'active']),
            'out_of_stock': len([r for r in rewards_data if r['status'] == 'out_of_stock']),
            'redeemed_today': len(Transaction.get_transactions_by_type('redeem', limit=100))
        }
        
        # Get top redeemed rewards from transaction statistics
        try:
            transaction_stats = Transaction.get_transaction_statistics()
            popular_rewards = transaction_stats.get('popular_rewards', [])
            
            top_redeemed_data = []
            
            # Check if popular_rewards has data and handle both dict and tuple formats
            if popular_rewards:
                for i, reward_info in enumerate(popular_rewards[:3], 1):
                    # Handle if it's a tuple or dict
                    if isinstance(reward_info, dict):
                        top_redeemed_data.append({
                            'name': reward_info.get('reward_name', 'Unknown'),
                            'count': reward_info.get('count', 0),
                            'points': reward_info.get('cost', 0),
                            'rank': i
                        })
                    elif isinstance(reward_info, (list, tuple)) and len(reward_info) >= 3:
                        # If it's a tuple like (name, count, cost)
                        top_redeemed_data.append({
                            'name': reward_info[0] if len(reward_info) > 0 else 'Unknown',
                            'count': reward_info[1] if len(reward_info) > 1 else 0,
                            'points': reward_info[2] if len(reward_info) > 2 else 0,
                            'rank': i
                        })
        except Exception as e:
            print(f"Warning: Could not get transaction statistics: {e}")
            top_redeemed_data = []
        
        # Fallback if no popular rewards
        if not top_redeemed_data and len(rewards_data) > 0:
            for i, reward in enumerate(rewards_data[:3], 1):
                top_redeemed_data.append({
                    'name': reward['name'],
                    'count': max(1, 100 - reward['cost']),  # Simulated
                    'points': reward['cost'],
                    'rank': i
                })
        
    except Exception as e:
        print(f"Error in rewards route: {e}")
        import traceback
        traceback.print_exc()
        rewards_data = []
        stats = {'total_rewards': 0, 'active_rewards': 0, 'out_of_stock': 0, 'redeemed_today': 0}
        top_redeemed_data = []
        department_names = []
    
    return render_template('rewards.html', 
                         rewards=rewards_data, 
                         stats=stats, 
                         top_redeemed=top_redeemed_data,
                         departments=department_names)

# Rewards CRUD API endpoints
@app.route('/api/rewards/add', methods=['POST'])
@login_required
def api_add_reward():
    try:
        data = request.get_json()
        
        # Validate required fields
        name = data.get('name', '').strip()
        cost = int(data.get('cost', 0))
        stock = int(data.get('stock', 0))
        department = data.get('department', '').strip()
        
        if not name or cost <= 0 or stock < 0 or not department:
            return {'success': False, 'message': 'Invalid input data'}, 400
        
        # Create new reward
        reward = Reward(
            name=name,
            cost=cost,
            stock=stock,
            department=department,
            image_url=data.get('image_url', ''),
            created_by=g.current_user.full_name if g.current_user else 'Admin',
            status='active' if stock > 0 else 'out_of_stock'
        )
        
        if reward.save():
            _notify_admins(
                '🎁 New Reward Added',
                f'"{name}" added to {department} ({stock} in stock)',
                notif_type='reward', priority='low'
            )
            return {'success': True, 'message': 'Reward added successfully', 'reward_id': reward.id}
        else:
            return {'success': False, 'message': 'Failed to add reward'}, 500
            
    except Exception as e:
        print(f"Error adding reward: {e}")
        return {'success': False, 'message': str(e)}, 500

@app.route('/api/rewards/edit/<reward_id>', methods=['POST'])
@login_required
def api_edit_reward(reward_id):
    try:
        reward = Reward.get_reward_by_id(reward_id)
        if not reward:
            return {'success': False, 'message': 'Reward not found'}, 404
        
        data = request.get_json()
        
        # Update fields
        reward.name = data.get('name', reward.name).strip()
        reward.cost = int(data.get('cost', reward.cost))
        reward.stock = int(data.get('stock', reward.stock))
        reward.department = data.get('department', reward.department).strip()
        reward.image_url = data.get('image_url', reward.image_url)
        
        # Update status based on stock
        if reward.stock == 0:
            reward.status = 'out_of_stock'
        elif reward.stock > 0:
            reward.status = 'active'
        
        if reward.save():
            return {'success': True, 'message': 'Reward updated successfully'}
        else:
            return {'success': False, 'message': 'Failed to update reward'}, 500
            
    except Exception as e:
        print(f"Error editing reward: {e}")
        return {'success': False, 'message': str(e)}, 500

@app.route('/api/rewards/restock/<reward_id>', methods=['POST'])
@login_required
def api_restock_reward(reward_id):
    try:
        reward = Reward.get_reward_by_id(reward_id)
        if not reward:
            return {'success': False, 'message': 'Reward not found'}, 404
        
        data = request.get_json()
        quantity = int(data.get('quantity', 0))
        
        if quantity <= 0:
            return {'success': False, 'message': 'Invalid quantity'}, 400
        
        if reward.add_stock(quantity):
            return {'success': True, 'message': f'Added {quantity} items to stock', 'new_stock': reward.stock}
        else:
            return {'success': False, 'message': 'Failed to restock reward'}, 500
            
    except Exception as e:
        print(f"Error restocking reward: {e}")
        return {'success': False, 'message': str(e)}, 500

@app.route('/api/rewards/delete/<reward_id>', methods=['POST'])
@login_required
def api_delete_reward(reward_id):
    try:
        reward = Reward.get_reward_by_id(reward_id)
        if not reward:
            return {'success': False, 'message': 'Reward not found'}, 404
        
        if reward.delete():
            _notify_admins(
                '🗑️ Reward Removed',
                f'"{reward.name}" ({reward.department}) was deleted',
                notif_type='reward', priority='low'
            )
            return {'success': True, 'message': 'Reward deleted successfully'}
        else:
            return {'success': False, 'message': 'Failed to delete reward'}, 500
            
    except Exception as e:
        print(f"Error deleting reward: {e}")
        return {'success': False, 'message': str(e)}, 500

@app.route('/api/rewards/get/<reward_id>', methods=['GET'])
@login_required
def api_get_reward(reward_id):
    try:
        reward = Reward.get_reward_by_id(reward_id)
        if not reward:
            return {'success': False, 'message': 'Reward not found'}, 404
        
        return {
            'success': True,
            'reward': {
                'id': reward.id,
                'name': reward.name,
                'cost': reward.cost,
                'stock': reward.stock,
                'department': reward.department,
                'image_url': reward.image_url,
                'status': reward.status
            }
        }
            
    except Exception as e:
        print(f"Error getting reward: {e}")
        return {'success': False, 'message': str(e)}, 500

# ===== TRANSACTION API ENDPOINTS =====

@app.route('/api/transactions/verify/<transaction_id>', methods=['POST'])
@login_required
def api_verify_transaction(transaction_id):
    """Verify a pending transaction."""
    try:
        transaction = Transaction.get_transaction_by_id(transaction_id)
        if not transaction:
            return {'success': False, 'message': 'Transaction not found'}, 404
        
        # Update status to completed
        if transaction.update_status('completed'):
            _notify_admins(
                '✅ Transaction Verified',
                f'Transaction {transaction_id[:8]}… verified by {session.get("user_name", "Admin")}',
                notif_type='transaction', priority='normal'
            )
            return {
                'success': True,
                'message': 'Transaction verified successfully',
                'transaction_id': transaction_id
            }
        else:
            return {'success': False, 'message': 'Failed to verify transaction'}, 500
            
    except Exception as e:
        print(f"Error verifying transaction: {e}")
        import traceback
        traceback.print_exc()
        return {'success': False, 'message': str(e)}, 500

@app.route('/api/transactions/reject/<transaction_id>', methods=['POST'])
@login_required
def api_reject_transaction(transaction_id):
    """Reject a pending transaction."""
    try:
        transaction = Transaction.get_transaction_by_id(transaction_id)
        if not transaction:
            return {'success': False, 'message': 'Transaction not found'}, 404
        
        # Update status to cancelled
        if transaction.update_status('cancelled'):
            _notify_admins(
                '❌ Transaction Rejected',
                f'Transaction {transaction_id[:8]}… was rejected by {session.get("user_name", "Admin")}',
                notif_type='transaction', priority='normal'
            )
            return {
                'success': True,
                'message': 'Transaction rejected successfully',
                'transaction_id': transaction_id
            }
        else:
            return {'success': False, 'message': 'Failed to reject transaction'}, 500
            
    except Exception as e:
        print(f"Error rejecting transaction: {e}")
        import traceback
        traceback.print_exc()
        return {'success': False, 'message': str(e)}, 500

@app.route('/api/transactions/get/<transaction_id>', methods=['GET'])
@login_required
def api_get_transaction(transaction_id):
    """Get detailed transaction information."""
    try:
        transaction = Transaction.get_transaction_by_id(transaction_id)
        if not transaction:
            return {'success': False, 'message': 'Transaction not found'}, 404
        
        # Get user information
        user_name = transaction.student_name or 'Unknown User'
        user_department = transaction.department or 'Unknown'
        
        if not transaction.student_name:
            student = Student.get_student_by_id(transaction.user_id)
            if student:
                user_name = student.full_name
                user_department = student.department
        
        return {
            'success': True,
            'transaction': {
                'id': transaction.id,
                'user_id': transaction.user_id,
                'user_name': user_name,
                'department': user_department,
                'type': transaction.type,
                'points': transaction.points,
                'reward_id': transaction.reward_id,
                'reward_name': transaction.reward_name,
                'ticket_code': transaction.ticket_code,
                'status': transaction.status,
                'timestamp': transaction.timestamp.isoformat() if transaction.timestamp else None,
                'date': transaction.timestamp.strftime('%Y-%m-%d %H:%M') if transaction.timestamp else 'Unknown'
            }
        }
            
    except Exception as e:
        print(f"Error getting transaction: {e}")
        import traceback
        traceback.print_exc()
        return {'success': False, 'message': str(e)}, 500

@app.route('/transactions')
@login_required
def transactions():
    try:
        # Pagination parameters
        page = request.args.get('page', 1, type=int)
        per_page = 10
        
        # Get all transactions with real data
        all_transactions = Transaction.get_all_transactions()
        transaction_stats = Transaction.get_transaction_statistics()
        daily_stats = Transaction.get_daily_statistics()
        
        # Get department names from database (only active departments)
        department_names = sorted(Department.get_department_names(include_inactive=False))
        
        # Format transactions for template
        transactions_data = []
        for transaction in all_transactions:
            # Get user information - handle both new and old structures
            user_name = 'Unknown User'
            user_department = 'Unknown'
            
            if hasattr(transaction, 'student_name') and transaction.student_name:
                user_name = transaction.student_name
            else:
                # Fallback to fetching student data
                student = Student.get_student_by_id(transaction.user_id)
                if student:
                    user_name = student.full_name
                    user_department = student.department
            
            if hasattr(transaction, 'department') and transaction.department:
                user_department = transaction.department
            
            # Format transaction data
            transactions_data.append({
                'id': transaction.id,
                'short_id': transaction.id[:8].upper() if transaction.id else 'N/A',
                'user': user_name,
                'department': user_department,
                'type': transaction.type,
                'points': abs(transaction.points),
                'reward': transaction.reward_name if transaction.type == 'redeem' else None,
                'ticket': transaction.ticket_code or 'N/A',
                'status': transaction.status,
                'timestamp': transaction.timestamp,
                'date': transaction.timestamp.strftime('%Y-%m-%d %H:%M') if transaction.timestamp else 'Unknown',
                'date_only': transaction.timestamp.strftime('%Y-%m-%d') if transaction.timestamp else 'Unknown',
                'time_only': transaction.timestamp.strftime('%H:%M') if transaction.timestamp else 'Unknown'
            })
        
        # Compile statistics
        stats = {
            'total_deposits': transaction_stats.get('total_deposits', 0),
            'total_redemptions': transaction_stats.get('total_redemptions', 0),
            'pending_tickets': transaction_stats.get('pending_redemptions', 0),
            'deposits_today': daily_stats.get('deposits', 0),
            'redemptions_today': daily_stats.get('redemptions', 0),
            'points_today': daily_stats.get('points_earned', 0)
        }
        
        # Calculate pagination
        total_transactions = len(transactions_data)
        total_pages = (total_transactions + per_page - 1) // per_page  # Ceiling division
        start_index = (page - 1) * per_page
        end_index = start_index + per_page
        paginated_transactions = transactions_data[start_index:end_index]
        
        # Pagination info
        pagination = {
            'page': page,
            'per_page': per_page,
            'total': total_transactions,
            'total_pages': total_pages,
            'has_prev': page > 1,
            'has_next': page < total_pages,
            'prev_page': page - 1 if page > 1 else None,
            'next_page': page + 1 if page < total_pages else None,
            'pages': list(range(1, min(total_pages + 1, 6)))  # Show max 5 page numbers
        }
        
    except Exception as e:
        print(f"Error in transactions route: {e}")
        import traceback
        traceback.print_exc()
        paginated_transactions = []
        stats = {
            'total_deposits': 0,
            'total_redemptions': 0,
            'pending_tickets': 0,
            'deposits_today': 0,
            'redemptions_today': 0,
            'points_today': 0
        }
        department_names = []
        pagination = {
            'page': 1,
            'per_page': 10,
            'total': 0,
            'total_pages': 0,
            'has_prev': False,
            'has_next': False,
            'prev_page': None,
            'next_page': None,
            'pages': [1]
        }
    
    return render_template('transactions.html', 
                         transactions=paginated_transactions, 
                         stats=stats,
                         departments=department_names,
                         pagination=pagination)

@app.route('/machine_monitor')
@login_required
def machine_monitor():
    try:
        from services.firebase_service import db as _db
        from models.admin_model import Admin

        # ── Real stats from students (Arduino bridge writes directly to students) ──
        today_start = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)

        def _local_dt(ts):
            if ts is None:
                return None
            if hasattr(ts, 'tzinfo') and ts.tzinfo is not None:
                return ts.astimezone().replace(tzinfo=None)
            return ts

        all_student_docs = list(_db.collection('students').stream())
        bottles_today = 0
        total_lifetime_bottles = 0

        for doc in all_student_docs:
            d = doc.to_dict()
            lifetime = int(d.get('totalBottlesLifetime') or 0)
            total_lifetime_bottles += lifetime
            lu = _local_dt(d.get('lastUpdated') or d.get('updatedAt') or d.get('lastActivityAt'))
            if lu and lu >= today_start and lifetime > 0:
                bottles_today += 1

        # ── Admins (teacher accounts) ──
        all_admins = Admin.get_all_admins()
        admins_list = [
            {
                'id': a.id,
                'name': a.name,
                'email': a.email,
                'department': a.department,
                'position': a.position,
            }
            for a in all_admins if a.name
        ]

        # ── Machine documents ──
        all_machines = Machine.get_all_machines()

        machines_data = []
        for machine in all_machines:
            last_maintenance = 'Never'
            if machine.last_maintenance:
                lm = _local_dt(machine.last_maintenance)
                if lm:
                    last_maintenance = lm.strftime('%Y-%m-%d')

            last_online_str = 'Never'
            if machine.last_online:
                lo = _local_dt(machine.last_online)
                if lo:
                    last_online_str = lo.strftime('%Y-%m-%d %H:%M')

            machines_data.append({
                'doc_id': machine.id,
                'id': machine.machine_id,
                'name': getattr(machine, 'name', None) or f"T2T Machine {machine.machine_id}",
                'location': machine.location or 'Main Campus',
                'status': machine.status,
                'capacity': machine.get_fill_percentage(),
                'current_bottles': machine.current_bottles,
                'max_capacity': machine.capacity,
                'bottles_today': bottles_today,
                'bottles_total': total_lifetime_bottles,
                'last_maintenance': last_maintenance,
                'last_online': last_online_str,
                'assigned_admin_id': machine.assigned_admin_id or '',
                'assigned_admin_name': machine.assigned_admin_name or machine.updated_by or 'Unassigned',
                'maintenance_schedule': machine.maintenance_schedule,
                'notes': machine.notes or ''
            })

        stats = {
            'online_machines': sum(1 for m in all_machines if m.status == 'active'),
            'full_machines': sum(1 for m in all_machines if m.status == 'full'),
            'offline_machines': sum(1 for m in all_machines if m.status in ('offline', 'error')),
            'bottles_today': bottles_today,
            'total_bottles': total_lifetime_bottles,
        }

    except Exception as e:
        print(f"Error in machine_monitor route: {e}")
        import traceback; traceback.print_exc()
        machines_data = []
        admins_list = []
        stats = {'online_machines': 0, 'full_machines': 0, 'offline_machines': 0, 'bottles_today': 0, 'total_bottles': 0}

    return render_template('machine_monitor.html', machines=machines_data, stats=stats, admins=admins_list)


# ─────────────────────────────────────────────
# Machine API routes
# ─────────────────────────────────────────────

@app.route('/api/machine/add', methods=['POST'])
@login_required
def api_machine_add():
    try:
        data = request.get_json(force=True)
        import uuid
        machine_id = data.get('machine_id') or f"MCN-{uuid.uuid4().hex[:6].upper()}"
        machine = Machine(
            machine_id=machine_id,
            name=data.get('name', '').strip(),
            location=data.get('location', '').strip(),
            capacity=int(data.get('capacity', 100)),
            current_bottles=0,
            status='active',
            notes=data.get('notes', ''),
            assigned_admin_id=data.get('assigned_admin_id', ''),
            assigned_admin_name=data.get('assigned_admin_name', ''),
            updated_by=data.get('assigned_admin_name', '')
        )
        if machine.save():
            return jsonify({'success': True, 'doc_id': machine.id, 'machine_id': machine_id})
        return jsonify({'success': False, 'error': 'Failed to save machine'}), 500
    except Exception as e:
        print(f"Error in api_machine_add: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/machine/<doc_id>/assign_admin', methods=['POST'])
@login_required
def api_machine_assign_admin(doc_id):
    try:
        data = request.get_json(force=True)
        machine = Machine.get_machine_by_id(doc_id)
        if not machine:
            return jsonify({'success': False, 'error': 'Machine not found'}), 404
        machine.assigned_admin_id = data.get('admin_id', '')
        machine.assigned_admin_name = data.get('admin_name', '')
        machine.updated_by = data.get('admin_name', '')
        if machine.save():
            return jsonify({'success': True})
        return jsonify({'success': False, 'error': 'Save failed'}), 500
    except Exception as e:
        print(f"Error in api_machine_assign_admin: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/machine/<doc_id>/reset', methods=['POST'])
@login_required
def api_machine_reset(doc_id):
    try:
        machine = Machine.get_machine_by_id(doc_id)
        if not machine:
            return jsonify({'success': False, 'error': 'Machine not found'}), 404
        current_user_name = session.get('user_name', 'Admin')
        if machine.set_active(updated_by=current_user_name):
            return jsonify({'success': True})
        return jsonify({'success': False, 'error': 'Reset failed'}), 500
    except Exception as e:
        print(f"Error in api_machine_reset: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/machine/<doc_id>/collect', methods=['POST'])
@login_required
def api_machine_collect(doc_id):
    try:
        data = request.get_json(force=True)
        machine = Machine.get_machine_by_id(doc_id)
        if not machine:
            return jsonify({'success': False, 'error': 'Machine not found'}), 404
        bottles = int(data.get('bottles_collected', machine.current_bottles))
        performed_by = data.get('performed_by', session.get('user_name', 'Admin'))
        machine.collect_bottles(bottles, updated_by=performed_by)
        machine.perform_maintenance(
            'bottle_collection',
            updated_by=performed_by,
            notes=f'Collected {bottles} bottles'
        )
        return jsonify({'success': True, 'bottles_collected': bottles})
    except Exception as e:
        print(f"Error in api_machine_collect: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/machine/<doc_id>/details')
@login_required
def api_machine_details(doc_id):
    try:
        from services.firebase_service import db as _db
        machine = Machine.get_machine_by_id(doc_id)
        if not machine:
            return jsonify({'success': False, 'error': 'Machine not found'}), 404

        def _fmt_ts(ts):
            if ts is None:
                return 'Never'
            if hasattr(ts, 'tzinfo') and ts.tzinfo:
                ts = ts.astimezone().replace(tzinfo=None)
            try:
                return ts.strftime('%Y-%m-%d %H:%M')
            except Exception:
                return str(ts)

        # Maintenance logs for this machine
        logs_docs = (
            _db.collection('maintenance_logs')
            .where('machineId', '==', machine.machine_id)
            .limit(50)
            .stream()
        )
        raw_logs = []
        for doc in logs_docs:
            d = doc.to_dict()
            raw_logs.append(d)
        # Sort by timestamp descending client-side, take last 10
        raw_logs.sort(key=lambda x: x.get('timestamp') or datetime.min, reverse=True)
        raw_logs = raw_logs[:10]
        logs = []
        for d in raw_logs:
            logs.append({
                'date': _fmt_ts(d.get('timestamp')),
                'action': (d.get('maintenanceType') or 'maintenance').replace('_', ' ').title(),
                'details': d.get('notes') or '-',
                'performed_by': d.get('performedBy') or d.get('updatedBy') or 'System',
            })

        machine_dict = {
            'doc_id': machine.id,
            'id': machine.machine_id,
            'name': machine.name,
            'location': machine.location,
            'status': machine.status,
            'capacity': machine.get_fill_percentage(),
            'current_bottles': machine.current_bottles,
            'max_capacity': machine.capacity,
            'last_maintenance': _fmt_ts(machine.last_maintenance),
            'last_online': _fmt_ts(machine.last_online),
            'assigned_admin_name': machine.assigned_admin_name or machine.updated_by or 'Unassigned',
            'maintenance_schedule': machine.maintenance_schedule,
            'notes': machine.notes or '',
            'bottles_collected': machine.bottles_collected,
            'days_since_maintenance': machine.get_days_since_maintenance(),
        }
        return jsonify({'success': True, 'machine': machine_dict, 'logs': logs})
    except Exception as e:
        print(f"Error in api_machine_details: {e}")
        import traceback; traceback.print_exc()
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/machine/<doc_id>/chart_data')
@login_required
def api_machine_chart_data(doc_id):
    try:
        from services.firebase_service import db as _db
        machine = Machine.get_machine_by_id(doc_id)
        if not machine:
            return jsonify({'success': False, 'error': 'Machine not found'}), 404

        since = datetime.now() - timedelta(days=30)

        def _norm_ts(ts):
            if ts is None:
                return None
            if hasattr(ts, 'tzinfo') and ts.tzinfo:
                ts = ts.astimezone().replace(tzinfo=None)
            return ts

        # Build ordered last-30-days labels
        labels = []
        for i in range(29, -1, -1):
            day = datetime.now() - timedelta(days=i)
            labels.append(day.strftime('%b %d'))

        # --- Dataset 1: bottle_collection maintenance logs (per machine) ---
        collection_daily = {}
        coll_docs = (
            _db.collection('maintenance_logs')
            .where('machineId', '==', machine.machine_id)
            .limit(200)
            .stream()
        )
        for doc in coll_docs:
            d = doc.to_dict()
            if d.get('maintenanceType') != 'bottle_collection':
                continue
            ts = _norm_ts(d.get('timestamp'))
            if ts and ts >= since:
                key = ts.strftime('%b %d')
                notes = d.get('notes', '')
                bottles = 0
                try:
                    bottles = int(notes.split('Collected ')[1].split(' bottles')[0])
                except Exception:
                    bottles = 1
                collection_daily[key] = collection_daily.get(key, 0) + bottles

        # --- Dataset 2: deposit transactions (site-wide, best proxy for activity) ---
        deposit_daily = {}
        txn_docs = (
            _db.collection('transactions')
            .where('type', '==', 'deposit')
            .limit(500)
            .stream()
        )
        for doc in txn_docs:
            d = doc.to_dict()
            ts = _norm_ts(d.get('timestamp') or d.get('createdAt'))
            if ts and ts >= since:
                key = ts.strftime('%b %d')
                deposit_daily[key] = deposit_daily.get(key, 0) + 1

        collection_values = [collection_daily.get(lbl, 0) for lbl in labels]
        deposit_values = [deposit_daily.get(lbl, 0) for lbl in labels]

        return jsonify({
            'success': True,
            'labels': labels,
            'data': collection_values,          # bottle collection events (per machine)
            'deposit_data': deposit_values,     # student deposits (site-wide)
            'has_collection_data': any(v > 0 for v in collection_values),
            'has_deposit_data': any(v > 0 for v in deposit_values),
        })
    except Exception as e:
        print(f"Error in api_machine_chart_data: {e}")
        import traceback; traceback.print_exc()
        return jsonify({'success': False, 'error': str(e)}), 500


# ─────────────────────────────────────────────
# Machine Notification / Task routes
# ─────────────────────────────────────────────

@app.route('/api/machine/<doc_id>/notify_admin', methods=['POST'])
@login_required
def api_machine_notify_admin(doc_id):
    """Create a task notification for the machine's assigned admin."""
    try:
        from services.firebase_service import db as _db
        data = request.get_json(force=True)
        machine = Machine.get_machine_by_id(doc_id)
        if not machine:
            return jsonify({'success': False, 'error': 'Machine not found'}), 404

        if not machine.assigned_admin_id:
            return jsonify({'success': False, 'error': 'No admin assigned to this machine. Please assign an admin first.'}), 400

        notif_type = data.get('type', 'empty_machine')  # 'empty_machine' | 'schedule_maintenance'
        message = data.get('message', '').strip()
        priority = data.get('priority', 'normal')
        created_by = session.get('user_name', 'Super User')

        if not message:
            machine_label = machine.name or machine.machine_id
            loc = machine.location or 'campus'
            if notif_type == 'empty_machine':
                message = f"Machine '{machine_label}' at {loc} needs to be emptied."
            else:
                message = f"Please perform maintenance on '{machine_label}' at {loc}."

        notif_doc = {
            'machineDocId': doc_id,
            'machineId': machine.machine_id,
            'machineName': machine.name or machine.machine_id,
            'machineLocation': machine.location or '',
            'assignedAdminId': machine.assigned_admin_id,
            'assignedAdminName': machine.assigned_admin_name or '',
            'type': notif_type,
            'message': message,
            'priority': priority,
            'status': 'pending',
            'createdAt': datetime.now(),
            'createdBy': created_by,
            'completedAt': None,
            'completedBy': None,
            'completionNote': None,
        }

        ref = _db.collection('machine_notifications').add(notif_doc)
        return jsonify({'success': True, 'notif_id': ref[1].id})
    except Exception as e:
        print(f"Error in api_machine_notify_admin: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/machine_notifications')
@login_required
def api_machine_notifications_list():
    """List all machine task notifications (for super user panel)."""
    try:
        from services.firebase_service import db as _db

        def _fmt(ts):
            if ts is None:
                return None
            if hasattr(ts, 'tzinfo') and ts.tzinfo:
                ts = ts.astimezone().replace(tzinfo=None)
            try:
                return ts.strftime('%Y-%m-%d %H:%M')
            except Exception:
                return str(ts)

        docs = list(_db.collection('machine_notifications').stream())
        notifications = []
        for doc in docs:
            d = doc.to_dict()
            notifications.append({
                'id': doc.id,
                'machineDocId': d.get('machineDocId', ''),
                'machineId': d.get('machineId', ''),
                'machineName': d.get('machineName', ''),
                'machineLocation': d.get('machineLocation', ''),
                'assignedAdminId': d.get('assignedAdminId', ''),
                'assignedAdminName': d.get('assignedAdminName', 'Unassigned'),
                'type': d.get('type', ''),
                'message': d.get('message', ''),
                'priority': d.get('priority', 'normal'),
                'status': d.get('status', 'pending'),
                'createdAt': _fmt(d.get('createdAt')),
                'createdBy': d.get('createdBy', ''),
                'completedAt': _fmt(d.get('completedAt')),
                'completedBy': d.get('completedBy', ''),
                'completionNote': d.get('completionNote', ''),
            })

        notifications.sort(key=lambda x: x.get('createdAt') or '', reverse=True)
        pending_count = sum(1 for n in notifications if n['status'] == 'pending')
        return jsonify({'success': True, 'notifications': notifications, 'pending_count': pending_count})
    except Exception as e:
        print(f"Error in api_machine_notifications_list: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/machine_notifications/<notif_id>/complete', methods=['POST'])
@login_required
def api_machine_notification_complete(notif_id):
    """Mark a task notification as done and perform the machine action."""
    try:
        from services.firebase_service import db as _db
        data = request.get_json(force=True) or {}
        note = data.get('note', '').strip()
        completed_by = data.get('completed_by', session.get('user_name', 'Admin'))

        notif_ref = _db.collection('machine_notifications').document(notif_id)
        notif_doc = notif_ref.get()
        if not notif_doc.exists:
            return jsonify({'success': False, 'error': 'Notification not found'}), 404

        notif_data = notif_doc.to_dict()
        notif_ref.update({
            'status': 'done',
            'completedAt': datetime.now(),
            'completedBy': completed_by,
            'completionNote': note,
        })

        # Perform the actual machine action
        machine_doc_id = notif_data.get('machineDocId', '')
        notif_type = notif_data.get('type', '')
        if machine_doc_id:
            machine = Machine.get_machine_by_id(machine_doc_id)
            if machine:
                if notif_type == 'empty_machine':
                    bottles = machine.current_bottles
                    machine.collect_bottles(bottles, updated_by=completed_by)
                    machine.perform_maintenance(
                        'bottle_collection', updated_by=completed_by,
                        notes=f'Collected {bottles} bottles. {note}'.strip()
                    )
                elif notif_type == 'schedule_maintenance':
                    machine.perform_maintenance(
                        'routine', updated_by=completed_by,
                        notes=f'Maintenance completed. {note}'.strip()
                    )

        return jsonify({'success': True})
    except Exception as e:
        print(f"Error in api_machine_notification_complete: {e}")
        import traceback; traceback.print_exc()
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/reports')
@login_required
def reports():
    try:
        # Get current date/time
        now = datetime.now()
        today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
        today_end = now.replace(hour=23, minute=59, second=59, microsecond=999999)
        
        print(f"\n🔍 DEBUG REPORTS ROUTE:")
        print(f"   Current time: {now}")
        print(f"   Today range: {today_start} to {today_end}")
        
        # Yesterday
        yesterday_start = (today_start - timedelta(days=1))
        yesterday_end = today_start - timedelta(microseconds=1)
        
        # This week (Monday to Sunday)
        week_start = today_start - timedelta(days=today_start.weekday())
        
        # Last week
        last_week_start = week_start - timedelta(days=7)
        last_week_end = week_start - timedelta(microseconds=1)
        
        # This month
        month_start = today_start.replace(day=1)
        
        # Last month
        if month_start.month == 1:
            last_month_start = month_start.replace(year=month_start.year - 1, month=12)
        else:
            last_month_start = month_start.replace(month=month_start.month - 1)
        last_month_end = month_start - timedelta(microseconds=1)
        
        # Get comprehensive statistics
        student_stats = Student.get_student_statistics()
        transaction_stats = Transaction.get_transaction_statistics()
        department_stats = Department.get_department_statistics()
        machine_stats = Machine.get_machine_statistics()
        reward_stats = Reward.get_reward_statistics()
        
        # Get all transactions for period calculations
        all_transactions = Transaction.get_all_transactions()
        print(f"   Total transactions: {len(all_transactions)}")
        
        if len(all_transactions) > 0:
            print(f"   First transaction timestamp: {all_transactions[0].timestamp}")
            print(f"   First transaction type: {type(all_transactions[0].timestamp)}")
        
        # Helper function to convert timestamp to datetime if needed
        def get_datetime(timestamp):
            if timestamp is None:
                return None
            if isinstance(timestamp, datetime):
                # Convert UTC timezone-aware to local naive datetime
                return timestamp.astimezone().replace(tzinfo=None) if timestamp.tzinfo else timestamp
            # Handle Firestore timestamp
            if hasattr(timestamp, 'timestamp'):
                return datetime.fromtimestamp(timestamp.timestamp())
            return None
        
        # Helper function to calculate statistics for a period
        def calculate_period_stats(start_date, end_date, period_name):
            period_transactions = []
            for t in all_transactions:
                t_time = get_datetime(t.timestamp)
                if t_time and start_date <= t_time <= end_date:
                    period_transactions.append(t)
            
            print(f"\n   Period: {period_name}")
            print(f"   Range: {start_date} to {end_date}")
            print(f"   Transactions found: {len(period_transactions)}")
            
            deposits = [t for t in period_transactions if t.type == 'deposit']
            redemptions = [t for t in period_transactions if t.type == 'redeem']
            completed_redemptions = [t for t in redemptions if t.status.lower() == 'completed']
            
            # Calculate bottles (1 deposit = 1 bottle) and points
            bottles = len(deposits)
            
            # Calculate points issued in this period
            points_issued = sum(t.points for t in deposits)
            
            # Get unique users in this period
            unique_users = len(set(t.user_id for t in period_transactions if t.user_id))
            
            # Find top department for this period (count ALL transactions, not just deposits)
            dept_points = {}
            for t in period_transactions:  # Changed from 'deposits' to 'period_transactions'
                dept = t.department if t.department else 'Unknown'
                if dept and dept != 'Unknown':
                    # For deposits, add points; for redemptions, also add points (activity metric)
                    dept_points[dept] = dept_points.get(dept, 0) + abs(t.points)
            
            print(f"   Department points: {dept_points}")
            
            top_dept = max(dept_points, key=dept_points.get) if dept_points else 'N/A'
            
            # Calculate machine uptime
            total_machines = machine_stats.get('total_machines', 0)
            active_machines = machine_stats.get('active_machines', 0)
            uptime = f"{(active_machines / total_machines * 100):.1f}%" if total_machines > 0 else "0%"
            
            return {
                'period': period_name,
                'bottles': bottles,
                'points': points_issued,
                'rewards': len(completed_redemptions),
                'users': unique_users,
                'top_dept': top_dept,
                'uptime': uptime
            }
        
        # Calculate statistics for each period
        analytics_data = [
            calculate_period_stats(today_start, today_end, 'Today'),
            calculate_period_stats(yesterday_start, yesterday_end, 'Yesterday'),
            calculate_period_stats(week_start, today_end, 'This Week'),
            calculate_period_stats(last_week_start, last_week_end, 'Last Week'),
            calculate_period_stats(month_start, today_end, 'This Month'),
            calculate_period_stats(last_month_start, last_month_end, 'Last Month')
        ]
        
        # Calculate weekly trend data — 7-day window ending at window_end_day (00:00 local)
        def build_7day_trend(window_end_day):
            trend = []
            for i in range(6, -1, -1):
                day_start = window_end_day - timedelta(days=i)
                day_end = day_start.replace(hour=23, minute=59, second=59, microsecond=999999)
                day_txns = []
                for t in all_transactions:
                    t_time = get_datetime(t.timestamp)
                    if t_time and day_start <= t_time <= day_end:
                        day_txns.append(t)
                deposits = [t for t in day_txns if t.type == 'deposit']
                # Prefer deposit count; fall back to all-activity count when no deposits exist
                if deposits:
                    count = len(deposits)
                    pts = sum(t.points for t in deposits)
                else:
                    count = len(day_txns)
                    pts = sum(t.points for t in day_txns)
                trend.append({
                    'date': day_start.strftime('%a %d'),
                    'bottles': count,
                    'points': pts,
                    'users': len(set(t.user_id for t in day_txns if t.user_id))
                })
                print(f"   {day_start.strftime('%Y-%m-%d %a')}: {len(day_txns)} txns, {count} activity, {pts} pts")
            return trend

        print(f"\n📈 WEEKLY TREND CALCULATION:")
        weekly_trend = build_7day_trend(today_start)

        # If last 7 calendar days are all empty, fall back to window ending at most recent activity
        if all(d['bottles'] == 0 and d['points'] == 0 for d in weekly_trend) and all_transactions:
            tx_times = [get_datetime(t.timestamp) for t in all_transactions]
            tx_times = [t for t in tx_times if t is not None]
            if tx_times:
                most_recent_day = max(tx_times).replace(hour=0, minute=0, second=0, microsecond=0)
                print(f"   ⚠️ No recent calendar activity — showing window ending {most_recent_day.date()}")
                weekly_trend = build_7day_trend(most_recent_day)

        print(f"\n   Weekly trend result: {weekly_trend}")
        
        # Calculate department performance (top 5)
        all_departments = Department.get_all_departments()
        dept_performance = []
        for dept in all_departments:
            dept_students = Student.get_students_by_department(dept.name)
            total_points = sum(student.points for student in dept_students)
            if total_points > 0:
                dept_performance.append({
                    'name': dept.name,
                    'points': total_points
                })
        
        dept_performance = sorted(dept_performance, key=lambda x: x['points'], reverse=True)[:5]
        
        # Calculate reward redemption statistics (count from transactions)
        # Get all redemption transactions
        redemption_transactions = [t for t in all_transactions if t.type == 'redeem']
        
        # Count redemptions by reward name
        reward_redemptions = {}
        for trans in redemption_transactions:
            reward_name = trans.reward_name if trans.reward_name else 'Unknown'
            reward_redemptions[reward_name] = reward_redemptions.get(reward_name, 0) + 1
        
        # Sort and get top 5 most redeemed rewards
        reward_categories = sorted(reward_redemptions.items(), key=lambda x: x[1], reverse=True)[:5]
        
        # Key metrics with comparison to last period
        this_week_stats = analytics_data[2]  # This Week
        last_week_stats = analytics_data[3]  # Last Week
        
        def calculate_change(current, previous):
            if previous == 0:
                return 100 if current > 0 else 0
            return round(((current - previous) / previous) * 100, 1)
        
        key_metrics = {
            'total_bottles': {
                'value': this_week_stats['bottles'],
                'change': calculate_change(this_week_stats['bottles'], last_week_stats['bottles'])
            },
            'points_circulated': {
                'value': this_week_stats['points'],
                'change': calculate_change(this_week_stats['points'], last_week_stats['points'])
            },
            'active_users': {
                'value': this_week_stats['users'],
                'change': calculate_change(this_week_stats['users'], last_week_stats['users'])
            },
            'rewards_redeemed': {
                'value': this_week_stats['rewards'],
                'change': calculate_change(this_week_stats['rewards'], last_week_stats['rewards'])
            },
            'machine_uptime': {
                'value': this_week_stats['uptime'],
                'change': 0  # Uptime doesn't have meaningful change percentage
            }
        }
        
        # Get department names for filters
        department_names = [dept.name for dept in all_departments]
        
        return render_template('reports.html', 
                             analytics_data=analytics_data,
                             weekly_trend=weekly_trend,
                             dept_performance=dept_performance,
                             reward_categories=reward_categories,
                             key_metrics=key_metrics,
                             departments=department_names)
        
    except Exception as e:
        print(f"Error in reports route: {e}")
        import traceback
        traceback.print_exc()
        
        # Return empty data structure on error
        empty_key_metrics = {
            'total_bottles': {'value': 0, 'change': 0},
            'points_circulated': {'value': 0, 'change': 0},
            'active_users': {'value': 0, 'change': 0},
            'rewards_redeemed': {'value': 0, 'change': 0},
            'machine_uptime': {'value': '0%', 'change': 0}
        }
        
        return render_template('reports.html', 
                             analytics_data=[],
                             weekly_trend=[],
                             dept_performance=[],
                             reward_categories=[],
                             key_metrics=empty_key_metrics,
                             departments=[])

# ===== REPORT GENERATION & EXPORT API ENDPOINTS =====

@app.route('/api/reports/export/<report_type>/<format>', methods=['GET', 'POST'])
@login_required
def api_export_report(report_type, format):
    """Export report as PDF or Excel"""
    try:
        from services.report_service import ReportService
        from flask import send_file
        
        print(f"\n📄 EXPORTING REPORT: {report_type} as {format}")
        
        # Get filter parameters
        if request.method == 'POST':
            data = request.get_json()
            date_range = data.get('date_range', 'week')
            department_filter = data.get('department')
            report_filter = data.get('report_filter', 'overview')
        else:
            date_range = request.args.get('date_range', 'week')
            department_filter = request.args.get('department')
            report_filter = request.args.get('report_filter', 'overview')

        # Auto-map named report types to appropriate date ranges
        _type_to_range = {'daily': 'today', 'weekly': 'week', 'monthly': 'month'}
        if report_type in _type_to_range:
            date_range = _type_to_range[report_type]
        
        print(f"   Filters: date_range={date_range}, department={department_filter}, filter={report_filter}")
        
        # Get report data based on type and filters
        report_data = _get_filtered_report_data(report_type, date_range, department_filter, report_filter)
        
        # Initialize report service
        report_service = ReportService()
        
        # Generate report
        if format.lower() == 'pdf':
            buffer = report_service.generate_pdf_report(report_data, report_type)
            mimetype = 'application/pdf'
            extension = 'pdf'
        elif format.lower() in ['excel', 'xlsx']:
            buffer = report_service.generate_excel_report(report_data, report_type)
            mimetype = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
            extension = 'xlsx'
        elif format.lower() == 'csv':
            buffer = _generate_csv_report(report_data, report_type)
            mimetype = 'text/csv'
            extension = 'csv'
        else:
            return jsonify({'success': False, 'message': 'Invalid format'}), 400
        
        # Generate filename
        filename = f"t2t_{report_type}_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.{extension}"
        
        print(f"   ✅ Report generated: {filename}")
        
        return send_file(
            buffer,
            mimetype=mimetype,
            as_attachment=True,
            download_name=filename
        )
        
    except Exception as e:
        print(f"❌ Error exporting report: {e}")
        traceback.print_exc()
        return jsonify({'success': False, 'message': str(e)}), 500

@app.route('/api/reports/custom', methods=['POST'])
@login_required
def api_generate_custom_report():
    """Generate custom report with user-specified parameters"""
    try:
        from services.report_service import ReportService
        from flask import send_file
        
        data = request.get_json()
        print(f"\n📊 GENERATING CUSTOM REPORT:")
        print(f"   Data: {data}")
        
        # Extract parameters
        report_name = data.get('report_name', 'Custom Report')
        date_from = data.get('date_from')
        date_to = data.get('date_to')
        departments = data.get('departments', [])
        format_type = data.get('format', 'pdf')
        
        # Include sections
        include_overview = data.get('include_overview', True)
        include_recycling = data.get('include_recycling', True)
        include_departments = data.get('include_departments', True)
        include_rewards = data.get('include_rewards', False)
        include_machines = data.get('include_machines', False)
        include_users = data.get('include_users', False)
        
        print(f"   Date Range: {date_from} to {date_to}")
        print(f"   Departments: {departments}")
        print(f"   Format: {format_type}")
        
        # Get custom report data
        report_data = _get_custom_report_data(
            date_from, date_to, departments,
            include_overview, include_recycling, include_departments,
            include_rewards, include_machines, include_users
        )
        
        report_data['report_name'] = report_name
        report_data['include_overview'] = include_overview
        report_data['include_departments'] = include_departments
        report_data['include_rewards'] = include_rewards
        
        # Initialize report service
        report_service = ReportService()
        
        # Generate report
        if format_type.lower() == 'pdf':
            buffer = report_service.generate_pdf_report(report_data, 'custom')
            mimetype = 'application/pdf'
            extension = 'pdf'
        elif format_type.lower() in ['excel', 'xlsx']:
            buffer = report_service.generate_excel_report(report_data, 'custom')
            mimetype = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
            extension = 'xlsx'
        elif format_type.lower() == 'csv':
            buffer = _generate_csv_report(report_data, 'custom')
            mimetype = 'text/csv'
            extension = 'csv'
        else:
            return jsonify({'success': False, 'message': 'Invalid format'}), 400
        
        # Generate filename
        safe_name = report_name.replace(' ', '_').lower()
        filename = f"t2t_{safe_name}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.{extension}"
        
        print(f"   ✅ Custom report generated: {filename}")
        
        return send_file(
            buffer,
            mimetype=mimetype,
            as_attachment=True,
            download_name=filename
        )
        
    except Exception as e:
        print(f"❌ Error generating custom report: {e}")
        traceback.print_exc()
        return jsonify({'success': False, 'message': str(e)}), 500

@app.route('/api/reports/schedule', methods=['POST'])
@login_required
def api_schedule_report():
    """Schedule automated report generation and email delivery"""
    try:
        data = request.get_json()
        print(f"\n📅 SCHEDULING REPORT:")
        print(f"   Data: {data}")
        
        report_type = data.get('report_type', 'daily')
        frequency = data.get('frequency', 'daily')
        emails = data.get('emails', '')
        format_type = data.get('format', 'pdf')
        
        # Parse email addresses
        email_list = [email.strip() for email in emails.split(',') if email.strip()]
        
        if not email_list:
            return jsonify({'success': False, 'message': 'At least one email address is required'}), 400
        
        # Store schedule in Firestore
        schedule_data = {
            'report_type': report_type,
            'frequency': frequency,
            'emails': email_list,
            'format': format_type,
            'created_by': session.get('user_email', 'unknown'),
            'created_at': datetime.now(),
            'status': 'active',
            'last_run': None,
            'next_run': _calculate_next_run(frequency)
        }
        
        # Save to Firestore
        schedule_ref = db.collection('report_schedules').add(schedule_data)
        
        print(f"   ✅ Report scheduled successfully: {schedule_ref[1].id}")
        print(f"   Recipients: {email_list}")
        print(f"   Next run: {schedule_data['next_run']}")
        
        return jsonify({
            'success': True,
            'message': f'{report_type.capitalize()} report scheduled to run {frequency}',
            'schedule_id': schedule_ref[1].id,
            'next_run': schedule_data['next_run'].isoformat() if schedule_data['next_run'] else None
        }), 200
        
    except Exception as e:
        print(f"❌ Error scheduling report: {e}")
        traceback.print_exc()
        return jsonify({'success': False, 'message': str(e)}), 500

@app.route('/api/reports/update-filters', methods=['POST'])
@login_required
def api_update_report_filters():
    """Update reports view with filtered data"""
    try:
        data = request.get_json()
        print(f"\n🔍 UPDATING REPORT FILTERS:")
        print(f"   Filters: {data}")
        
        date_range = data.get('date_range', 'week')
        department = data.get('department')
        report_type = data.get('report_type', 'overview')
        
        # Get filtered report data
        report_data = _get_filtered_report_data('overview', date_range, department, report_type)
        
        print(f"   ✅ Filtered data retrieved")
        
        return jsonify({
            'success': True,
            'data': {
                'analytics_data': report_data.get('analytics_data', []),
                'weekly_trend': report_data.get('weekly_trend', []),
                'dept_performance': report_data.get('dept_performance', []),
                'reward_categories': report_data.get('reward_categories', []),
                'key_metrics': report_data.get('key_metrics', {})
            }
        }), 200
        
    except Exception as e:
        print(f"❌ Error updating filters: {e}")
        traceback.print_exc()
        return jsonify({'success': False, 'message': str(e)}), 500

# Helper functions for report generation

def _get_filtered_report_data(report_type, date_range, department_filter, report_filter):
    """Get report data based on filters"""
    try:
        # Calculate date range
        now = datetime.now()
        today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
        
        if date_range == 'today':
            start_date = today_start
            end_date = now
        elif date_range == 'week':
            start_date = today_start - timedelta(days=today_start.weekday())
            end_date = now
        elif date_range == 'month':
            start_date = today_start.replace(day=1)
            end_date = now
        elif date_range == 'quarter':
            quarter_month = ((now.month - 1) // 3) * 3 + 1
            start_date = today_start.replace(month=quarter_month, day=1)
            end_date = now
        elif date_range == 'year':
            start_date = today_start.replace(month=1, day=1)
            end_date = now
        else:
            start_date = today_start - timedelta(days=7)
            end_date = now
        
        print(f"   Date range calculated: {start_date} to {end_date}")
        
        # Get all transactions and filter
        all_transactions = Transaction.get_all_transactions()
        
        # Helper to convert timestamp
        def get_datetime(timestamp):
            if timestamp is None:
                return None
            if isinstance(timestamp, datetime):
                return timestamp.astimezone().replace(tzinfo=None) if timestamp.tzinfo else timestamp
            if hasattr(timestamp, 'timestamp'):
                return datetime.fromtimestamp(timestamp.timestamp())
            return None
        
        # Filter by date range
        filtered_transactions = []
        for t in all_transactions:
            trans_date = get_datetime(t.timestamp)
            if trans_date and start_date <= trans_date <= end_date:
                # Filter by department if specified
                if department_filter:
                    if hasattr(t, 'department') and t.department == department_filter:
                        filtered_transactions.append(t)
                else:
                    filtered_transactions.append(t)
        
        print(f"   Filtered transactions: {len(filtered_transactions)}")
        
        # Calculate analytics based on filtered data
        deposits = [t for t in filtered_transactions if t.type == 'deposit']
        redemptions = [t for t in filtered_transactions if t.type == 'redeem']
        
        total_bottles = len(deposits)
        total_points = sum(t.points for t in deposits)
        total_rewards = len(redemptions)
        unique_users = len(set(t.user_id for t in filtered_transactions if t.user_id))
        
        # Calculate department performance (line preserved below)
        dept_points = {}
        for t in filtered_transactions:
            dept = t.department if hasattr(t, 'department') and t.department else 'Unknown'
            if dept and dept != 'Unknown':
                if dept not in dept_points:
                    dept_points[dept] = {'points': 0, 'bottles': 0, 'users': set()}
                dept_points[dept]['points'] += abs(t.points)
                if t.type == 'deposit':
                    dept_points[dept]['bottles'] += 1
                if t.user_id:
                    dept_points[dept]['users'].add(t.user_id)
        
        dept_performance = [
            {
                'name': dept,
                'points': data['points'],
                'bottles': data['bottles'],
                'users': len(data['users'])
            }
            for dept, data in dept_points.items()
        ]
        dept_performance.sort(key=lambda x: x['points'], reverse=True)
        
        # Calculate reward categories
        reward_counts = {}
        for t in redemptions:
            reward_name = t.reward_name if hasattr(t, 'reward_name') and t.reward_name else 'Unknown'
            reward_counts[reward_name] = reward_counts.get(reward_name, 0) + 1
        
        reward_categories = sorted(reward_counts.items(), key=lambda x: x[1], reverse=True)
        
        # Calculate weekly trend (last 7 days)
        weekly_trend = []
        for i in range(6, -1, -1):
            day_start = today_start - timedelta(days=i)
            day_end = day_start + timedelta(days=1) - timedelta(microseconds=1)
            
            day_transactions = [t for t in filtered_transactions 
                               if get_datetime(t.timestamp) and day_start <= get_datetime(t.timestamp) <= day_end]
            
            day_deposits = [t for t in day_transactions if t.type == 'deposit']
            day_redemptions = [t for t in day_transactions if t.type == 'redeem']
            
            bottles = sum(t.points // 5 for t in day_deposits) if day_deposits else sum(t.points // 5 for t in day_redemptions)
            points = sum(t.points for t in day_deposits) if day_deposits else sum(t.points for t in day_redemptions)
            
            weekly_trend.append({
                'date': day_start.strftime('%a'),
                'bottles': bottles,
                'points': points,
                'users': len(set(t.user_id for t in day_transactions if t.user_id))
            })
        
        # Prepare report data
        report_data = {
            'key_metrics': {
                'total_bottles': {'value': total_bottles, 'change': 0},
                'points_circulated': {'value': total_points, 'change': 0},
                'active_users': {'value': unique_users, 'change': 0},
                'rewards_redeemed': {'value': total_rewards, 'change': 0},
                'machine_uptime': {'value': '95%', 'change': 0}
            },
            'analytics_data': [
                {
                    'period': f'{date_range.capitalize()} Total',
                    'bottles': total_bottles,
                    'points': total_points,
                    'rewards': total_rewards,
                    'users': unique_users,
                    'top_dept': dept_performance[0]['name'] if dept_performance else 'N/A',
                    'uptime': '95%'
                }
            ],
            'weekly_trend': weekly_trend,
            'dept_performance': dept_performance,
            'reward_categories': reward_categories,
            'date_range': date_range,
            'department_filter': department_filter,
            'report_filter': report_filter
        }
        
        return report_data
        
    except Exception as e:
        print(f"Error getting filtered report data: {e}")
        traceback.print_exc()
        raise

def _get_custom_report_data(date_from, date_to, departments, include_overview, 
                            include_recycling, include_departments, include_rewards, 
                            include_machines, include_users):
    """Get custom report data based on user specifications"""
    try:
        # Parse dates
        start_date = datetime.strptime(date_from, '%Y-%m-%d')
        end_date = datetime.strptime(date_to, '%Y-%m-%d').replace(hour=23, minute=59, second=59)
        
        print(f"   Custom date range: {start_date} to {end_date}")
        
        # Get all transactions and filter
        all_transactions = Transaction.get_all_transactions()
        
        # Helper to convert timestamp
        def get_datetime(timestamp):
            if timestamp is None:
                return None
            if isinstance(timestamp, datetime):
                return timestamp.astimezone().replace(tzinfo=None) if timestamp.tzinfo else timestamp
            if hasattr(timestamp, 'timestamp'):
                return datetime.fromtimestamp(timestamp.timestamp())
            return None
        
        # Filter by date range and departments
        filtered_transactions = []
        for t in all_transactions:
            trans_date = get_datetime(t.timestamp)
            if trans_date and start_date <= trans_date <= end_date:
                if departments and len(departments) > 0:
                    if hasattr(t, 'department') and t.department in departments:
                        filtered_transactions.append(t)
                else:
                    filtered_transactions.append(t)
        
        print(f"   Custom filtered transactions: {len(filtered_transactions)}")
        
        # Calculate metrics similar to standard report
        deposits = [t for t in filtered_transactions if t.type == 'deposit']
        redemptions = [t for t in filtered_transactions if t.type == 'redeem']
        
        total_bottles = len(deposits)
        total_points = sum(t.points for t in deposits)
        total_rewards = len(redemptions)
        unique_users = len(set(t.user_id for t in filtered_transactions if t.user_id))
        
        # Department performance (if included)
        dept_performance = []
        if include_departments:
            dept_points = {}
            for t in filtered_transactions:
                dept = t.department if hasattr(t, 'department') and t.department else 'Unknown'
                if dept and dept != 'Unknown':
                    if dept not in dept_points:
                        dept_points[dept] = {'points': 0, 'bottles': 0, 'users': set()}
                    dept_points[dept]['points'] += abs(t.points)
                    if t.type == 'deposit':
                        dept_points[dept]['bottles'] += 1
                    if t.user_id:
                        dept_points[dept]['users'].add(t.user_id)
            
            dept_performance = [
                {
                    'name': dept,
                    'points': data['points'],
                    'bottles': data['bottles'],
                    'users': len(data['users'])
                }
                for dept, data in dept_points.items()
            ]
            dept_performance.sort(key=lambda x: x['points'], reverse=True)
        
        # Reward categories (if included)
        reward_categories = []
        if include_rewards:
            reward_counts = {}
            for t in redemptions:
                reward_name = t.reward_name if hasattr(t, 'reward_name') and t.reward_name else 'Unknown'
                reward_counts[reward_name] = reward_counts.get(reward_name, 0) + 1
            
            reward_categories = sorted(reward_counts.items(), key=lambda x: x[1], reverse=True)
        
        # Prepare report data
        report_data = {
            'key_metrics': {
                'total_bottles': {'value': total_bottles, 'change': 0},
                'points_circulated': {'value': total_points, 'change': 0},
                'active_users': {'value': unique_users, 'change': 0},
                'rewards_redeemed': {'value': total_rewards, 'change': 0},
                'machine_uptime': {'value': '95%', 'change': 0}
            },
            'analytics_data': [
                {
                    'period': f'{date_from} to {date_to}',
                    'bottles': total_bottles,
                    'points': total_points,
                    'rewards': total_rewards,
                    'users': unique_users,
                    'top_dept': dept_performance[0]['name'] if dept_performance else 'N/A',
                    'uptime': '95%'
                }
            ],
            'weekly_trend': [],  # Not applicable for custom range
            'dept_performance': dept_performance,
            'reward_categories': reward_categories
        }
        
        return report_data
        
    except Exception as e:
        print(f"Error getting custom report data: {e}")
        traceback.print_exc()
        raise

def _generate_csv_report(report_data, report_type):
    """Generate CSV report"""
    import csv
    
    buffer = io.StringIO()
    writer = csv.writer(buffer)
    
    # Write header
    writer.writerow([f'Trash to Treasure - {report_type.capitalize()} Report'])
    writer.writerow([f'Generated: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}'])
    writer.writerow([])
    
    # Write analytics data
    if report_data.get('analytics_data'):
        writer.writerow(['Period Analytics'])
        writer.writerow(['Period', 'Bottles', 'Points', 'Rewards', 'Users', 'Top Department', 'Uptime'])
        for period in report_data['analytics_data']:
            writer.writerow([
                period.get('period', ''),
                period.get('bottles', 0),
                period.get('points', 0),
                period.get('rewards', 0),
                period.get('users', 0),
                period.get('top_dept', ''),
                period.get('uptime', '')
            ])
        writer.writerow([])
    
    # Write department data
    if report_data.get('dept_performance'):
        writer.writerow(['Department Performance'])
        writer.writerow(['Department', 'Points', 'Bottles', 'Users'])
        for dept in report_data['dept_performance']:
            writer.writerow([
                dept.get('name', ''),
                dept.get('points', 0),
                dept.get('bottles', 0),
                dept.get('users', 0)
            ])
        writer.writerow([])
    
    # Write reward data
    if report_data.get('reward_categories'):
        writer.writerow(['Reward Redemptions'])
        writer.writerow(['Reward Name', 'Count'])
        for reward_name, count in report_data['reward_categories']:
            writer.writerow([reward_name, count])
    
    # Convert to bytes
    bytes_buffer = io.BytesIO(buffer.getvalue().encode('utf-8'))
    bytes_buffer.seek(0)
    
    return bytes_buffer

def _calculate_next_run(frequency):
    """Calculate next scheduled run time"""
    now = datetime.now()
    
    if frequency == 'daily':
        # Schedule for 8 AM next day
        next_run = (now + timedelta(days=1)).replace(hour=8, minute=0, second=0, microsecond=0)
    elif frequency == 'weekly':
        # Schedule for next Monday 8 AM
        days_until_monday = (7 - now.weekday()) % 7 or 7
        next_run = (now + timedelta(days=days_until_monday)).replace(hour=8, minute=0, second=0, microsecond=0)
    elif frequency == 'monthly':
        # Schedule for 1st of next month 8 AM
        if now.month == 12:
            next_run = now.replace(year=now.year + 1, month=1, day=1, hour=8, minute=0, second=0, microsecond=0)
        else:
            next_run = now.replace(month=now.month + 1, day=1, hour=8, minute=0, second=0, microsecond=0)
    else:
        next_run = now + timedelta(days=1)
    
    return next_run

# ===== USER/ADMIN MANAGEMENT API ENDPOINTS =====

@app.route('/api/users/add-admin', methods=['POST'])
@login_required
def api_add_admin():
    """Add a new admin account with Firebase Authentication"""
    try:
        from firebase_admin import auth as firebase_auth
        
        data = request.get_json()
        print(f"[ADD ADMIN] Received data: {data}")
        
        # Validate required fields
        required_fields = ['name', 'email', 'employee_id', 'department', 'role', 'access_level', 'password']
        for field in required_fields:
            if not data.get(field):
                return jsonify({
                    'success': False,
                    'message': f'{field.replace("_", " ").title()} is required'
                }), 400
        
        # Check if email already exists in Firestore
        existing_admin = Admin.get_admin_by_email(data['email'])
        if existing_admin:
            return jsonify({
                'success': False,
                'message': 'An admin with this email already exists'
            }), 400
        
        # Check if email already exists in Firebase Auth
        try:
            existing_user = firebase_auth.get_user_by_email(data['email'])
            if existing_user:
                return jsonify({
                    'success': False,
                    'message': 'An account with this email already exists in Firebase Authentication'
                }), 400
        except firebase_auth.UserNotFoundError:
            # Good, email doesn't exist in Firebase Auth
            pass
        
        # Step 1: Create Firebase Authentication user
        try:
            firebase_user = firebase_auth.create_user(
                email=data['email'].lower(),
                password=data['password'],
                display_name=data['name'],
                disabled=False,
                email_verified=False  # Admin will verify on first login
            )
            print(f"[ADD ADMIN] Firebase Auth user created with UID: {firebase_user.uid}")
        except Exception as auth_error:
            print(f"[ADD ADMIN] Firebase Auth error: {auth_error}")
            return jsonify({
                'success': False,
                'message': f'Failed to create Firebase Auth user: {str(auth_error)}'
            }), 500
        
        # Step 2: Create admin record in Firestore
        new_admin = Admin(
            id=firebase_user.uid,  # Use Firebase Auth UID as admin ID
            name=data['name'],
            email=data['email'].lower(),
            employee_id=data['employee_id'],
            department=data['department'],
            position=data.get('position', ''),
            role=data['role'],
            access_level=int(data['access_level']),
            phone_number=data.get('phone_number', ''),
            office_location=data.get('office_location', ''),
            office_hours=data.get('office_hours', ''),
            status='active',
            is_active=True,
            created_by=session.get('user_email', 'system')
        )
        
        print(f"[ADD ADMIN] Created admin object: {new_admin.name}")
        
        # Save to Firestore with Firebase Auth UID as document ID
        try:
            admin_ref = db.collection('admins').document(firebase_user.uid)
            admin_data = new_admin.to_dict()
            admin_ref.set(admin_data)
            new_admin.id = firebase_user.uid
            print(f"[ADD ADMIN] Admin saved to Firestore with UID: {firebase_user.uid}")
            
            # Store password separately for web login (backwards compatibility)
            admin_ref.update({'password': data['password']})
            print(f"[ADD ADMIN] Password stored for web login compatibility")

            _notify_admins(
                '\U0001f468\u200d\U0001f4bc New Admin Added',
                f"{data['name']} ({data['email']}) added as {data['role']}",
                notif_type='system', priority='high'
            )

            return jsonify({
                'success': True,
                'message': 'Admin account created successfully! They can now login to both web and mobile app.',
                'admin': {
                    'id': new_admin.id,
                    'uid': firebase_user.uid,
                    'name': new_admin.name,
                    'email': new_admin.email,
                    'department': new_admin.department,
                    'role': new_admin.role
                }
            }), 200
            
        except Exception as firestore_error:
            # Rollback: Delete Firebase Auth user if Firestore save fails
            print(f"[ADD ADMIN] Firestore error: {firestore_error}, rolling back Firebase Auth user")
            try:
                firebase_auth.delete_user(firebase_user.uid)
                print(f"[ADD ADMIN] Rolled back Firebase Auth user")
            except Exception as rollback_error:
                print(f"[ADD ADMIN] Rollback failed: {rollback_error}")
            
            return jsonify({
                'success': False,
                'message': f'Failed to save admin to database: {str(firestore_error)}'
            }), 500
            
    except Exception as e:
        print(f"[ADD ADMIN] Exception occurred: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({
            'success': False,
            'message': f'Server error: {str(e)}'
        }), 500

@app.route('/api/users/get/<user_id>', methods=['GET'])
@login_required
def api_get_user(user_id):
    """Get user details by ID"""
    try:
        role = request.args.get('role', 'student')
        print(f"[GET USER] Fetching {role} with ID: {user_id}")
        
        if role == 'student':
            user = Student.get_student_by_id(user_id)
            if user:
                user_data = {
                    'id_number': user.student_id,
                    'name': user.full_name,
                    'email': user.email,
                    'department': user.department,
                    'status': user.status,
                    'bottles': user.bottles,
                    'points': user.points,
                    'total_logins': user.total_sessions,
                    'last_login': user.last_login_at.strftime('%Y-%m-%d %H:%M:%S') if user.last_login_at else 'Never'
                }
        else:  # admin
            user = Admin.get_admin_by_id(user_id)
            if user:
                user_data = {
                    'id_number': user.employee_id,
                    'name': user.name,
                    'email': user.email,
                    'department': user.department,
                    'status': user.status,
                    'position': user.position,
                    'access_level': user.access_level,
                    'phone_number': user.phone_number,
                    'office_location': user.office_location,
                    'office_hours': user.office_hours,
                    'total_logins': user.total_logins,
                    'last_login': user.last_login_at.strftime('%Y-%m-%d %H:%M:%S') if user.last_login_at else 'Never'
                }
        
        if user:
            return jsonify({
                'success': True,
                'user': user_data
            }), 200
        else:
            return jsonify({
                'success': False,
                'message': 'User not found'
            }), 404
            
    except Exception as e:
        print(f"[GET USER] Exception occurred: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({
            'success': False,
            'message': f'Server error: {str(e)}'
        }), 500

@app.route('/api/users/edit/<user_id>', methods=['POST'])
@login_required
def api_edit_user(user_id):
    """Edit user details"""
    try:
        role = request.args.get('role', 'student')
        data = request.get_json()
        print(f"[EDIT USER] Updating {role} with ID: {user_id}")
        print(f"[EDIT USER] Data: {data}")
        
        if role == 'student':
            user = Student.get_student_by_id(user_id)
            if user:
                user.full_name = data.get('name', user.full_name)
                user.email = data.get('email', user.email)
                user.department = data.get('department', user.department)
                user.status = data.get('status', user.status)
                
                success = user.save()
        else:  # admin
            user = Admin.get_admin_by_id(user_id)
            if user:
                user.name = data.get('name', user.name)
                user.email = data.get('email', user.email)
                user.department = data.get('department', user.department)
                user.status = data.get('status', user.status)
                user.is_active = data.get('status', user.status) == 'active'
                user.position = data.get('position', user.position)
                user.phone_number = data.get('phone_number', user.phone_number)
                user.office_location = data.get('office_location', user.office_location)
                user.office_hours = data.get('office_hours', user.office_hours)
                
                success = user.save()
        
        if user and success:
            print(f"[EDIT USER] User updated successfully")
            return jsonify({
                'success': True,
                'message': 'User updated successfully'
            }), 200
        else:
            return jsonify({
                'success': False,
                'message': 'User not found or update failed'
            }), 404
            
    except Exception as e:
        print(f"[EDIT USER] Exception occurred: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({
            'success': False,
            'message': f'Server error: {str(e)}'
        }), 500

@app.route('/api/users/update-status/<user_id>', methods=['POST'])
@login_required
def api_update_user_status(user_id):
    """Update user status (approve/suspend/reactivate)"""
    try:
        role = request.args.get('role', 'student')
        data = request.get_json()
        new_status = data.get('status')
        reason = data.get('reason', '')
        
        print(f"[UPDATE STATUS] Updating {role} {user_id} to status: {new_status}")
        
        if role == 'student':
            user = Student.get_student_by_id(user_id)
        else:  # admin
            user = Admin.get_admin_by_id(user_id)
        
        if user:
            user.status = new_status
            if hasattr(user, 'is_active'):
                user.is_active = new_status == 'active'
            
            # Log suspension reason if provided
            if new_status == 'suspended' and reason:
                # You could add a suspension_reason field to your models
                # For now, we'll just log it
                print(f"[UPDATE STATUS] Suspension reason: {reason}")
            
            success = user.save()
            
            if success:
                print(f"[UPDATE STATUS] Status updated successfully")
                _notify_admins(
                    '\u26a0\ufe0f User Status Changed',
                    f'{role.title()} status updated to {new_status} by {session.get("user_name", "Admin")}',
                    notif_type='system', priority='normal'
                )
                return jsonify({
                    'success': True,
                    'message': f'User status updated to {new_status}'
                }), 200
            else:
                return jsonify({
                    'success': False,
                    'message': 'Failed to update status'
                }), 500
        else:
            return jsonify({
                'success': False,
                'message': 'User not found'
            }), 404
            
    except Exception as e:
        print(f"[UPDATE STATUS] Exception occurred: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({
            'success': False,
            'message': f'Server error: {str(e)}'
        }), 500

@app.route('/api/users/reset-password/<user_id>', methods=['POST'])
@login_required
def api_reset_password(user_id):
    """Reset user password"""
    try:
        role = request.args.get('role', 'student')
        data = request.get_json()
        new_password = data.get('password')
        send_email = data.get('send_email', False)
        
        print(f"[RESET PASSWORD] Resetting password for {role} {user_id}")
        
        if not new_password:
            return jsonify({
                'success': False,
                'message': 'New password is required'
            }), 400
        
        if role == 'student':
            user = Student.get_student_by_id(user_id)
        else:  # admin
            user = Admin.get_admin_by_id(user_id)
        
        if user:
            # In a real application, you would hash the password
            # For now, we'll store it as-is (THIS IS NOT SECURE - FIX IN PRODUCTION)
            # Note: Student model might not have a password field if using Firebase Auth
            if hasattr(user, 'password'):
                user.password = new_password
                success = user.save()
            else:
                # For Firebase Auth users, you'd need to use Firebase Admin SDK
                print(f"[RESET PASSWORD] Password field not available for {role}")
                return jsonify({
                    'success': False,
                    'message': 'Password reset not supported for this user type. Please use Firebase Auth.'
                }), 400
            
            if success:
                print(f"[RESET PASSWORD] Password reset successfully")
                
                # TODO: Send email notification if requested
                if send_email:
                    print(f"[RESET PASSWORD] Email notification would be sent to {user.email}")
                    # send_password_reset_email(user.email, new_password)
                
                return jsonify({
                    'success': True,
                    'message': 'Password reset successfully'
                }), 200
            else:
                return jsonify({
                    'success': False,
                    'message': 'Failed to reset password'
                }), 500
        else:
            return jsonify({
                'success': False,
                'message': 'User not found'
            }), 404
            
    except Exception as e:
        print(f"[RESET PASSWORD] Exception occurred: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({
            'success': False,
            'message': f'Server error: {str(e)}'
        }), 500

@app.route('/api/users/import-template', methods=['GET'])
@login_required
def api_users_import_template():
    """Download a CSV template for bulk student import."""
    import csv, io as _io
    buf = _io.StringIO()
    w = csv.writer(buf)
    w.writerow(['full_name', 'email', 'student_id', 'department', 'status'])
    w.writerow(['Juan Dela Cruz', 'juan@university.edu', 'STU-2024-001', 'Computer Science', 'active'])
    buf.seek(0)
    from flask import send_file as _sf
    return _sf(
        _io.BytesIO(buf.getvalue().encode('utf-8')),
        mimetype='text/csv',
        as_attachment=True,
        download_name='students_import_template.csv'
    )


@app.route('/api/users/bulk-import', methods=['POST'])
@login_required
def api_bulk_import_users():
    """Bulk import students from an uploaded CSV file."""
    import csv, io as _io
    try:
        if 'file' not in request.files:
            return jsonify({'success': False, 'message': 'No file uploaded'}), 400

        uploaded = request.files['file']
        if not uploaded.filename:
            return jsonify({'success': False, 'message': 'No file selected'}), 400

        filename_lower = uploaded.filename.lower()
        if not filename_lower.endswith('.csv'):
            return jsonify({'success': False, 'message': 'Only CSV files are supported'}), 400

        content = uploaded.read().decode('utf-8-sig')  # handle BOM
        reader = csv.DictReader(_io.StringIO(content))

        required_cols = {'full_name', 'email', 'student_id', 'department'}
        if not required_cols.issubset(set(c.strip().lower() for c in (reader.fieldnames or []))):
            return jsonify({
                'success': False,
                'message': f'CSV must contain columns: {", ".join(sorted(required_cols))}'
            }), 400

        imported, skipped, errors = 0, 0, []

        for row_idx, row in enumerate(reader, start=2):
            row = {k.strip().lower(): (v or '').strip() for k, v in row.items()}

            name       = row.get('full_name', '')
            email      = row.get('email', '').lower()
            student_id = row.get('student_id', '')
            department = row.get('department', '')
            status     = row.get('status', 'active')

            if not name or not email or not student_id or not department:
                errors.append(f'Row {row_idx}: missing required field(s)')
                skipped += 1
                continue

            # Skip if student already exists
            existing = Student.get_student_by_email(email) if hasattr(Student, 'get_student_by_email') else None
            if existing:
                errors.append(f'Row {row_idx}: student {email} already exists — skipped')
                skipped += 1
                continue

            new_student = Student(
                full_name=name,
                student_id=student_id,
                email=email,
                department=department,
                status=status if status in ('active', 'pending', 'suspended') else 'active',
            )
            if new_student.save():
                imported += 1
            else:
                errors.append(f'Row {row_idx}: failed to save {email}')
                skipped += 1

        return jsonify({
            'success': True,
            'imported': imported,
            'skipped': skipped,
            'errors': errors[:20],   # cap error list returned to client
            'message': f'{imported} student(s) imported, {skipped} skipped.'
        }), 200

    except Exception as e:
        print(f"[BULK IMPORT] Exception: {e}")
        import traceback; traceback.print_exc()
        return jsonify({'success': False, 'message': str(e)}), 500


@app.route('/users')
@login_required
def users():
    try:
        # Pagination parameters
        page = request.args.get('page', 1, type=int)
        per_page = 10
        
        # Get all students and admins
        all_students = Student.get_all_students()
        all_admins = Admin.get_all_admins()
        student_stats = Student.get_student_statistics()
        admin_stats = Admin.get_admin_statistics()
        
        # Get department names from database (only active departments)
        department_names = sorted(Department.get_department_names(include_inactive=False))
        
# Helper: normalise any timestamp (Firestore, tz-aware, or None) → naive local datetime
        def _ts_to_dt(ts):
            if ts is None:
                return None
            if isinstance(ts, datetime):
                return ts.astimezone().replace(tzinfo=None) if ts.tzinfo else ts
            if hasattr(ts, 'timestamp'):            # Firestore DatetimeWithNanoseconds
                return datetime.fromtimestamp(ts.timestamp())
            return None

        # Combine students and admins into a unified user list
        users_data = []

        # Add students to list
        for student in all_students:
            # Use the most recent of last_login_at / last_activity_at / updated_at
            raw_last = (
                getattr(student, 'last_login_at', None) or
                getattr(student, 'last_activity_at', None) or
                getattr(student, 'updated_at', None)
            )
            users_data.append({
                'id': student.id,
                'name': student.full_name,
                'email': student.email,
                'student_id': student.student_id,
                'department': student.department,
                'role': 'student',
                'status': student.status,
                'points': student.points,
                'bottles': student.bottles,
                'created_at': student.created_at,
                'total_logins': getattr(student, 'total_sessions', getattr(student, 'total_logins', 0)),
                'last_login': _ts_to_dt(raw_last)
            })

        # Add admins to list
        for admin in all_admins:
            users_data.append({
                'id': admin.id,
                'name': admin.name,
                'email': admin.email,
                'employee_id': admin.employee_id,
                'department': admin.department,
                'position': admin.position,
                'role': 'admin',
                'admin_role': admin.role,
                'status': admin.status,
                'access_level': admin.access_level,
                'created_at': admin.created_at,
                'total_logins': admin.total_logins,
                'last_login': _ts_to_dt(admin.last_login_at)
            })
        
        # Sort by created_at (newest first)
        users_data.sort(key=lambda x: x['created_at'] if x['created_at'] else datetime.min, reverse=True)
        
        # Calculate pagination
        total_users = len(users_data)
        total_pages = (total_users + per_page - 1) // per_page
        start_index = (page - 1) * per_page
        end_index = start_index + per_page
        paginated_users = users_data[start_index:end_index]
        
        # Pagination info
        pagination = {
            'page': page,
            'per_page': per_page,
            'total': total_users,
            'total_pages': total_pages,
            'has_prev': page > 1,
            'has_next': page < total_pages,
            'prev_page': page - 1 if page > 1 else None,
            'next_page': page + 1 if page < total_pages else None,
            'pages': list(range(1, min(total_pages + 1, 6)))
        }
        
        # Compile statistics (count from actual user lists for accuracy)
        active_student_count  = len([s for s in all_students if s.status == 'active'])
        pending_student_count = len([s for s in all_students if s.status == 'pending'])
        suspended_student_count = len([s for s in all_students if s.status in ('suspended', 'banned')])
        active_admin_count    = len([a for a in all_admins  if a.status == 'active'])
        suspended_admin_count = len([a for a in all_admins  if a.status == 'suspended'])

        stats = {
            'total_users': total_users,
            'total_students': len(all_students),
            'total_admins': len(all_admins),
            'active_users': active_student_count + active_admin_count,
            'pending_users': pending_student_count,
            'suspended_users': suspended_student_count + suspended_admin_count
        }
        
    except Exception as e:
        print(f"Error in users route: {e}")
        import traceback
        traceback.print_exc()
        paginated_users = []
        department_names = []
        stats = {
            'total_users': 0,
            'total_students': 0,
            'total_admins': 0,
            'active_users': 0,
            'pending_users': 0,
            'suspended_users': 0
        }
        pagination = {
            'page': 1,
            'per_page': 10,
            'total': 0,
            'total_pages': 0,
            'has_prev': False,
            'has_next': False,
            'prev_page': None,
            'next_page': None,
            'pages': [1]
        }
    
    return render_template('users.html', 
                         users=paginated_users, 
                         stats=stats,
                         departments=department_names,
                         pagination=pagination)

@app.route('/settings')
@login_required
def settings():
    try:
        user_id = session.get('user_id')
        user_type = session.get('user_type', 'super_user')
        current_user = None
        if user_type == 'super_user':
            current_user = SuperUser.get_by_id(user_id)
        if current_user is None:
            current_user = type('obj', (object,), {
                'full_name': session.get('user_name', ''),
                'email': session.get('user_email', ''),
                'phone_number': '',
                'two_factor_enabled': False,
                'profile_image_url': session.get('user_photo', ''),
            })()

        # Load departments
        all_departments = Department.get_all_departments()

        # Load machines for maintenance scheduling
        all_machines = Machine.get_all_machines() or []

        # Load technicians
        tech_docs = db.collection('admins').where('role', '==', 'technician').stream()
        technicians = [Admin.from_dict(d.id, d.to_dict()) for d in tech_docs]

        # Load system settings
        sys_settings = {}
        try:
            doc = db.collection('settings').document('system').get()
            if doc.exists:
                sys_settings = doc.to_dict()
        except Exception:
            pass

    except Exception as e:
        print(f"Settings route error: {e}")
        current_user = type('obj', (object,), {
            'full_name': '', 'email': '', 'phone_number': '',
            'two_factor_enabled': False, 'profile_image_url': '',
        })()
        all_departments = []
        all_machines = []
        technicians = []
        sys_settings = {}

    return render_template('settings.html',
                           current_user=current_user,
                           departments=all_departments,
                           machines=all_machines,
                           technicians=technicians,
                           sys_settings=sys_settings)


@app.route('/api/settings/maintenance', methods=['POST'])
@login_required
def api_settings_maintenance():
    """Schedule a maintenance visit for a machine."""
    try:
        data = request.get_json() or {}
        machine_id = data.get('machineId', '').strip()
        scheduled_date = data.get('scheduledDate', '').strip()
        maint_type = data.get('type', 'routine').strip()
        notes = data.get('notes', '').strip()
        assigned_to = data.get('assignedTo', '').strip()

        if not machine_id or not scheduled_date:
            return jsonify({'success': False, 'message': 'Machine and date are required.'}), 400

        db.collection('maintenance_schedules').add({
            'machineId': machine_id,
            'scheduledDate': scheduled_date,
            'type': maint_type,
            'notes': notes,
            'assignedTo': assigned_to,
            'status': 'scheduled',
            'createdAt': datetime.now(),
            'createdBy': session.get('user_email', 'system'),
        })
        return jsonify({'success': True, 'message': 'Maintenance scheduled successfully.'})
    except Exception as e:
        print(f"Maintenance schedule error: {e}")
        return jsonify({'success': False, 'message': 'Failed to schedule maintenance.'}), 500


@app.route('/api/settings/logs/export')
@login_required
def api_settings_logs_export():
    """Export recent transactions as a CSV log file."""
    try:
        import csv, io
        days = int(request.args.get('days', 30))
        since = datetime.now() - timedelta(days=days)

        docs = db.collection('transactions') \
                 .where('timestamp', '>=', since) \
                 .order_by('timestamp', direction='DESCENDING') \
                 .limit(500) \
                 .stream()

        output = io.StringIO()
        writer = csv.writer(output)
        writer.writerow(['Timestamp', 'Student ID', 'Type', 'Points', 'Status', 'Machine ID'])
        for doc in docs:
            d = doc.to_dict()
            ts = d.get('timestamp', '')
            try:
                ts = ts.strftime('%Y-%m-%d %H:%M:%S') if hasattr(ts, 'strftime') else str(ts)
            except Exception:
                ts = str(ts)
            writer.writerow([
                ts,
                d.get('studentId', d.get('student_id', '')),
                d.get('type', ''),
                d.get('points', ''),
                d.get('status', ''),
                d.get('machineId', d.get('machine_id', '')),
            ])

        output.seek(0)
        from flask import Response
        filename = f"system_logs_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
        return Response(
            output.getvalue(),
            mimetype='text/csv',
            headers={'Content-Disposition': f'attachment; filename="{filename}"'}
        )
    except Exception as e:
        print(f"Log export error: {e}")
        return jsonify({'success': False, 'message': 'Failed to export logs.'}), 500


@app.route('/api/settings/technicians', methods=['GET'])
@login_required
def api_settings_technicians_list():
    """List all technicians."""
    try:
        docs = db.collection('admins').where('role', '==', 'technician').stream()
        result = []
        for d in docs:
            td = d.to_dict()
            result.append({
                'id': d.id,
                'name': td.get('name', ''),
                'email': td.get('email', ''),
                'phone': td.get('phoneNumber', ''),
                'employeeId': td.get('employeeId', ''),
                'assignedMachine': td.get('assignedMachine', ''),
                'status': td.get('status', 'active'),
            })
        return jsonify({'success': True, 'technicians': result})
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500


@app.route('/api/settings/technicians', methods=['POST'])
@login_required
def api_settings_technicians_create():
    """Create a new technician."""
    try:
        data = request.get_json() or {}
        name = data.get('name', '').strip()
        email = data.get('email', '').strip()
        phone = data.get('phone', '').strip()
        employee_id = data.get('employeeId', '').strip()
        assigned_machine = data.get('assignedMachine', '').strip()

        if not name or not email:
            return jsonify({'success': False, 'message': 'Name and email are required.'}), 400

        # Check email uniqueness
        existing = db.collection('admins').where('email', '==', email).limit(1).stream()
        if any(True for _ in existing):
            return jsonify({'success': False, 'message': 'Email already in use.'}), 400

        now = datetime.now()
        ref = db.collection('admins').add({
            'name': name,
            'email': email,
            'phoneNumber': phone,
            'phone_number': phone,
            'employeeId': employee_id,
            'employee_id': employee_id,
            'assignedMachine': assigned_machine,
            'assigned_machine': assigned_machine,
            'role': 'technician',
            'status': 'active',
            'isActive': True,
            'permissions': ['manage_machines'],
            'accessLevel': 1,
            'createdAt': now,
            'createdBy': session.get('user_email', 'system'),
            'updatedAt': now,
        })
        new_id = ref[1].id
        return jsonify({'success': True, 'message': 'Technician created successfully.', 'id': new_id})
    except Exception as e:
        print(f"Technician create error: {e}")
        return jsonify({'success': False, 'message': 'Failed to create technician.'}), 500


@app.route('/api/settings/technicians/<tech_id>', methods=['DELETE'])
@login_required
def api_settings_technicians_delete(tech_id):
    """Deactivate (soft-delete) a technician."""
    try:
        db.collection('admins').document(tech_id).update({
            'status': 'inactive',
            'isActive': False,
            'updatedAt': datetime.now(),
        })
        return jsonify({'success': True, 'message': 'Technician removed.'})
    except Exception as e:
        print(f"Technician delete error: {e}")
        return jsonify({'success': False, 'message': 'Failed to remove technician.'}), 500


@app.route('/api/settings/profile/photo', methods=['POST'])
@login_required
def api_settings_profile_photo():
    """Upload/update super user profile photo (base64 data URL)."""
    try:
        data = request.get_json(force=True, silent=True) or {}
        user_id = session.get('user_id')
        photo_data = data.get('photoData', '')

        if not photo_data or not photo_data.startswith('data:image/'):
            return jsonify({'success': False, 'message': 'Invalid image data.'}), 400

        # Safety cap: base64 of a 200KB image is ~270KB; reject anything clearly oversized
        if len(photo_data) > 400_000:
            return jsonify({'success': False, 'message': 'Image too large. Please choose a smaller photo.'}), 413

        user = SuperUser.get_by_id(user_id)
        if not user:
            return jsonify({'success': False, 'message': 'User not found.'}), 404

        user.profile_image_url = photo_data
        user.save()
        # Store in session so the navbar reflects the change immediately
        session['user_photo'] = photo_data

        return jsonify({'success': True, 'message': 'Profile photo updated successfully.'})
    except Exception as e:
        print(f"Settings photo error: {e}")
        return jsonify({'success': False, 'message': f'Failed to update photo: {str(e)}'}), 500


@app.route('/api/settings/profile', methods=['POST'])
@login_required
def api_settings_profile():
    """Update super user profile."""
    try:
        data = request.get_json() or {}
        user_id = session.get('user_id')
        full_name = data.get('fullName', '').strip()
        phone = data.get('phone', '').strip()

        if not full_name:
            return jsonify({'success': False, 'message': 'Full name is required.'}), 400

        user = SuperUser.get_by_id(user_id)
        if not user:
            return jsonify({'success': False, 'message': 'User not found.'}), 404

        user.full_name = full_name
        user.phone_number = phone
        user.save()
        session['user_name'] = full_name

        return jsonify({'success': True, 'message': 'Profile updated successfully.'})
    except Exception as e:
        print(f"Settings profile error: {e}")
        return jsonify({'success': False, 'message': 'Failed to update profile.'}), 500


@app.route('/api/settings/password', methods=['POST'])
@login_required
def api_settings_password():
    """Change super user password."""
    try:
        data = request.get_json() or {}
        user_id = session.get('user_id')
        current_pw = data.get('currentPassword', '')
        new_pw = data.get('newPassword', '')
        confirm_pw = data.get('confirmPassword', '')

        if not current_pw or not new_pw or not confirm_pw:
            return jsonify({'success': False, 'message': 'All password fields are required.'}), 400

        if new_pw != confirm_pw:
            return jsonify({'success': False, 'message': 'New passwords do not match.'}), 400

        validation = SuperUser.validate_password(new_pw)
        if not validation.get('is_valid'):
            errors = ', '.join(validation.get('errors', ['Invalid password']))
            return jsonify({'success': False, 'message': errors}), 400

        user = SuperUser.get_by_id(user_id)
        if not user:
            return jsonify({'success': False, 'message': 'User not found.'}), 404

        if not SuperUser.verify_password(current_pw, user.password_hash, user.salt):
            return jsonify({'success': False, 'message': 'Current password is incorrect.'}), 400

        new_hash, new_salt = SuperUser.hash_password(new_pw)
        user.password_hash = new_hash
        user.salt = new_salt
        user.password_changed_at = datetime.now()
        user.save()

        return jsonify({'success': True, 'message': 'Password changed successfully.'})
    except Exception as e:
        print(f"Settings password error: {e}")
        return jsonify({'success': False, 'message': 'Failed to change password.'}), 500


@app.route('/api/settings/system', methods=['POST'])
@login_required
def api_settings_system():
    """Save system configuration settings."""
    try:
        data = request.get_json() or {}
        db.collection('settings').document('system').set({
            'pointsPerBottle': int(data.get('pointsPerBottle', 1)),
            'bonusMultiplier': float(data.get('bonusMultiplier', 1.0)),
            'minimumRedemption': int(data.get('minimumRedemption', 10)),
            'machineCapacity': int(data.get('machineCapacity', 100)),
            'maintenanceInterval': int(data.get('maintenanceInterval', 30)),
            'fullThreshold': int(data.get('fullThreshold', 90)),
            'updatedAt': datetime.now(),
            'updatedBy': session.get('user_email', 'system'),
        }, merge=True)
        return jsonify({'success': True, 'message': 'System settings saved.'})
    except Exception as e:
        print(f"Settings system error: {e}")
        return jsonify({'success': False, 'message': 'Failed to save settings.'}), 500

@app.route('/about')
def about():
    return render_template('about.html')

@app.route('/help-center')
def help_center():
    return render_template('help_center.html')

@app.route('/contact-us', methods=['GET', 'POST'])
def contact_us():
    if request.method == 'POST':
        name    = request.form.get('contact_name', '').strip()
        email   = request.form.get('contact_email', '').strip()
        subject = request.form.get('contact_subject', '').strip()
        message = request.form.get('contact_message', '').strip()
        priority = request.form.get('priority', 'low')
        dept    = request.form.get('contact_dept', '').strip()

        if not name or not email or not subject or not message:
            flash('Please fill in all required fields.', 'error')
        else:
            try:
                db.collection('contact_messages').add({
                    'name': name,
                    'email': email,
                    'subject': subject,
                    'message': message,
                    'priority': priority,
                    'department': dept,
                    'submitted_by': session.get('user_email', ''),
                    'status': 'new',
                    'created_at': datetime.now()
                })
                _notify_admins(
                    title=f'New Contact Message: {subject}',
                    body=f'{name} ({email}) sent a {priority}-priority message.',
                    notif_type='system',
                    priority='high' if priority in ('urgent', 'high') else 'normal'
                )
                flash(f'Message sent successfully! We will respond to {email} within 1–2 business days.', 'success')
            except Exception as e:
                print(f"Error saving contact message: {e}")
                flash('Failed to send message. Please try again.', 'error')

    return render_template('contact_us.html')

# ─────────────────────────────────────────────────────────────
# Admin: Contact Messages Inbox
# ─────────────────────────────────────────────────────────────

@app.route('/admin/messages')
@login_required
def admin_messages():
    from firebase_admin import firestore as fs
    status_filter   = request.args.get('status', 'all')
    priority_filter = request.args.get('priority', 'all')
    try:
        docs = (
            db.collection('contact_messages')
            .order_by('created_at', direction=fs.Query.DESCENDING)
            .stream()
        )
        all_msgs = []
        for doc in docs:
            data = doc.to_dict()
            data['id'] = doc.id
            ts = data.get('created_at')
            dt = None
            if hasattr(ts, 'seconds'):
                dt = datetime.fromtimestamp(ts.seconds)
            elif isinstance(ts, datetime):
                dt = ts
            # Replace raw Firestore Timestamp with ISO string so tojson works
            data['created_at'] = dt.isoformat() if dt else ''
            data['created_at_dt'] = dt.strftime('%b %d, %Y %I:%M %p') if dt else ''
            all_msgs.append(data)

        stats = {
            'total':    len(all_msgs),
            'new':      sum(1 for m in all_msgs if m.get('status') == 'new'),
            'read':     sum(1 for m in all_msgs if m.get('status') == 'read'),
            'replied':  sum(1 for m in all_msgs if m.get('status') == 'replied'),
            'archived': sum(1 for m in all_msgs if m.get('status') == 'archived'),
        }

        messages = all_msgs
        if status_filter != 'all':
            messages = [m for m in messages if m.get('status') == status_filter]
        if priority_filter != 'all':
            messages = [m for m in messages if m.get('priority') == priority_filter]

    except Exception as e:
        print(f"Error fetching contact messages: {e}")
        messages = []
        stats = {'total': 0, 'new': 0, 'read': 0, 'replied': 0, 'archived': 0}

    return render_template('messages.html', messages=messages, stats=stats,
                           status_filter=status_filter, priority_filter=priority_filter)


@app.route('/admin/messages/<doc_id>/update', methods=['POST'])
@login_required
def update_message_status(doc_id):
    new_status = request.form.get('status', 'read')
    if new_status not in {'new', 'read', 'replied', 'archived'}:
        return jsonify({'success': False, 'error': 'Invalid status'}), 400
    try:
        db.collection('contact_messages').document(doc_id).update({'status': new_status})
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/admin/messages/<doc_id>/delete', methods=['POST'])
@login_required
def delete_message(doc_id):
    try:
        db.collection('contact_messages').document(doc_id).delete()
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/report-issue', methods=['GET', 'POST'])
def report_issue():
    if request.method == 'POST':
        issue_type   = request.form.get('issue_type', '').strip()
        title        = request.form.get('issue_title', '').strip()
        description  = request.form.get('issue_description', '').strip()
        priority     = request.form.get('priority', 'low')
        machine_id   = request.form.get('machine_id', '').strip()
        location     = request.form.get('issue_location', '').strip()
        reporter_name  = request.form.get('reporter_name', '').strip()
        reporter_email = request.form.get('reporter_email', '').strip()

        if not issue_type or not title or not description:
            flash('Please fill in all required fields (Issue Type, Title, and Description).', 'error')
        else:
            try:
                db.collection('issue_reports').add({
                    'issue_type': issue_type,
                    'title': title,
                    'description': description,
                    'priority': priority,
                    'machine_id': machine_id,
                    'location': location,
                    'reporter_name': reporter_name,
                    'reporter_email': reporter_email,
                    'submitted_by': session.get('user_email', ''),
                    'status': 'open',
                    'created_at': datetime.now()
                })
                flash('Issue report submitted successfully! Our team will investigate and respond shortly.', 'success')
            except Exception as e:
                print(f"Error saving issue report: {e}")
                flash('Failed to submit report. Please try again.', 'error')

    return render_template('report_issue.html')

@app.route('/download-app')
@login_required
def download_app():
    """Redirect to the latest T2T Android APK download link."""
    return redirect('https://download856.mediafire.com/4kbdwykajy9gfHnL0q_W68HjDG2PNmy1afubj_6bZuB4JuyN37gPg1jzSM0bvzKtJOtl1IT-XMkOIr_EJYXHctHxqIKODCGSxkV-rDn4hvPo7DfC3lYOAQkrf5IH0pA1bOOtSWzT3jKX1k4apXtb9KTrI74UaDTWIdSlsF1Bap4Pzto/bpbf78jfmt5lv1i/app-release.apk')

# ===== NOTIFICATIONS API =====

@app.route('/api/notifications')
@login_required
def api_get_notifications():
    """Fetch recent admin broadcast notifications with unread count."""
    try:
        limit = min(int(request.args.get('limit', 20)), 50)

        # Avoid composite-index requirement by NOT using order_by with where();
        # fetch a wider window then sort in Python.
        docs = (
            db.collection('notifications')
            .where('userId', '==', 'admin')
            .limit(limit * 3)
            .stream()
        )

        notifications = []
        for doc in docs:
            d = doc.to_dict()
            created = d.get('createdAt')
            if hasattr(created, 'seconds'):
                # Firestore Timestamp → datetime
                dt = datetime.fromtimestamp(created.seconds)
                ts_str = dt.isoformat()
            elif hasattr(created, 'isoformat'):
                dt = created
                ts_str = created.isoformat()
            else:
                dt = datetime.min
                ts_str = ''
            notifications.append({
                'id':       doc.id,
                'title':    d.get('title', ''),
                'body':     d.get('body', ''),
                'type':     d.get('type', 'system'),
                'priority': d.get('priority', 'normal'),
                'created_at': ts_str,
                '_dt': dt,
            })

        # Sort newest-first in Python, then trim to limit
        notifications.sort(key=lambda x: x['_dt'], reverse=True)
        notifications = notifications[:limit]
        for n in notifications:
            del n['_dt']

        return jsonify({'success': True, 'notifications': notifications, 'unread_count': len(notifications)})
    except Exception as e:
        print(f"Error fetching notifications: {e}")
        traceback.print_exc()
        return jsonify({'success': True, 'notifications': [], 'unread_count': 0})


@app.route('/api/notifications/mark-read', methods=['POST'])
@login_required
def api_mark_notifications_read():
    """Record that the current user has seen all notifications up to now."""
    # The client tracks the read-watermark in localStorage; nothing to persist server-side.
    return jsonify({'success': True})


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port, debug=False)