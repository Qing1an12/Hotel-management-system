// Global state
let currentCustomerId = null;
let currentEmployeeId = null;
let isEmployee = false;

// Utility functions
function showLoading() {
    document.querySelector('.loading').style.display = 'block';
}

function hideLoading() {
    document.querySelector('.loading').style.display = 'none';
}

function showError(elementId, message) {
    const element = document.getElementById(elementId);
    const errorDiv = element.querySelector('.error-message') || document.createElement('div');
    errorDiv.className = 'error-message';
    errorDiv.textContent = message;
    if (!element.querySelector('.error-message')) {
        element.appendChild(errorDiv);
    }
    setTimeout(() => {
        errorDiv.remove();
    }, 5000);
}

function clearError(elementId) {
    const element = document.getElementById(elementId);
    const errorDiv = element.querySelector('.error-message');
    if (errorDiv) {
        errorDiv.remove();
    }
}

// Initialize the page
document.addEventListener('DOMContentLoaded', function() {
    // Set up user type switching
    document.querySelectorAll('input[name="userType"]').forEach(radio => {
        radio.addEventListener('change', function() {
            isEmployee = this.value === 'employee';
            document.querySelectorAll('.employee-only').forEach(el => {
                el.style.display = isEmployee ? 'block' : 'none';
            });
        });
    });

    // Customer registration form
    document.getElementById('customerRegistrationForm').addEventListener('submit', handleCustomerRegistration);

    // Search form
    document.getElementById('searchForm').addEventListener('submit', handleSearch);

    // Booking confirmation
    document.getElementById('confirmBooking').addEventListener('click', handleBookingConfirmation);

    // Load initial data
    loadHotelChains();

    // Set up event listeners
    document.getElementById('customerForm').addEventListener('submit', handleCustomerForm);
});

// API Functions
async function loadHotelChains() {
    try {
        showLoading();
        const response = await fetch('/api/hotel-chains');
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        const chains = await response.json();
        
        const select = document.getElementById('hotelChain');
        select.innerHTML = '<option value="">Any</option>';
        chains.forEach(chain => {
            const option = document.createElement('option');
            option.value = chain.name;
            option.textContent = chain.name;
            select.appendChild(option);
        });
    } catch (error) {
        console.error('Error loading hotel chains:', error);
        showError('hotelChain', 'Failed to load hotel chains');
    } finally {
        hideLoading();
    }
}

async function handleSearch(e) {
    e.preventDefault();
    clearError('searchResults');
    
    const startDate = document.getElementById('startDate').value;
    const endDate = document.getElementById('endDate').value;
    
    // Basic frontend validation
    if (!startDate || !endDate) {
        showError('searchResults', 'Please select both start and end dates');
        return;
    }

    const today = new Date();
    today.setHours(0, 0, 0, 0);
    
    const startDateObj = new Date(startDate);
    const endDateObj = new Date(endDate);
    
    if (startDateObj < today) {
        showError('searchResults', 'Start date cannot be in the past');
        return;
    }
    
    if (endDateObj <= startDateObj) {
        showError('searchResults', 'End date must be after start date');
        return;
    }

    try {
        showLoading();
        const params = new URLSearchParams({
            start_date: startDate,
            end_date: endDate
        });

        // Add optional parameters
        const optionalParams = {
            capacity: document.getElementById('capacity').value,
            area: document.getElementById('area').value,
            hotel_chain: document.getElementById('hotelChain').value,
            hotel_category: document.getElementById('hotelCategory').value,
            max_price: document.getElementById('maxPrice').value
        };

        for (const [key, value] of Object.entries(optionalParams)) {
            if (value) params.append(key, value);
        }

        console.log('Searching with params:', params.toString());
        const response = await fetch(`/api/available-rooms?${params}`);
        
        if (!response.ok) {
            const errorData = await response.json().catch(() => null);
            const errorMessage = errorData?.detail || `HTTP error! status: ${response.status}`;
            console.error('Server error:', errorMessage);
            throw new Error(errorMessage);
        }
        
        const data = await response.json();
        console.log('Search results:', data);
        
        if (!data) {
            throw new Error('No data received from server');
        }
        
        displaySearchResults(data);
    } catch (error) {
        console.error('Error searching rooms:', error);
        showError('searchResults', `Failed to search rooms: ${error.message}`);
    } finally {
        hideLoading();
    }
}

async function displaySearchResults(rooms) {
    const resultsDiv = document.getElementById('searchResults');
    resultsDiv.innerHTML = '';

    if (!rooms || rooms.length === 0) {
        resultsDiv.innerHTML = '<div class="alert alert-info">No rooms available for the selected criteria.</div>';
        return;
    }

    const container = document.createElement('div');
    container.className = 'row row-cols-1 row-cols-md-2 row-cols-lg-3 g-4';

    rooms.forEach(room => {
        const card = document.createElement('div');
        card.className = 'col';
        card.innerHTML = `
            <div class="card h-100">
                <div class="card-body">
                    <h5 class="card-title">Room ${room.roomid}</h5>
                    <h6 class="card-subtitle mb-2 text-muted">${room.chain_name}</h6>
                    <p class="card-text">
                        <strong>Price:</strong> $${room.price}/night<br>
                        <strong>Capacity:</strong> ${room.capacity} people<br>
                        <strong>View:</strong> ${room.view || 'Not specified'}<br>
                        <strong>Address:</strong> ${room.hotel_address}<br>
                        ${room.extendable ? '<span class="badge bg-success">Extendable</span>' : ''}
                    </p>
                    <button class="btn btn-primary" onclick="openBookingModal(${JSON.stringify(room).replace(/"/g, '&quot;')})">
                        Book Now
                    </button>
                </div>
            </div>
        `;
        container.appendChild(card);
    });

    resultsDiv.appendChild(container);
}

async function handleCustomerRegistration(e) {
    e.preventDefault();
    try {
        showLoading();
        const formData = {
            firstname: document.getElementById('customerFirstName').value,
            lastname: document.getElementById('customerLastName').value,
            address: document.getElementById('customerAddress').value
        };

        const response = await fetch('/api/customers', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(formData)
        });

        if (!response.ok) {
            const errorData = await response.json();
            throw new Error(errorData.detail || `HTTP error! status: ${response.status}`);
        }

        const result = await response.json();
        document.getElementById('customerRegistrationForm').reset();
        
        // Create and show success message
        const successMessage = `
            <div class="alert alert-success">
                <h4 class="alert-heading">Registration Successful!</h4>
                <p>Your Customer ID is: <strong>${result.customerid}</strong></p>
                <hr>
                <p class="mb-0">Please save this ID - you'll need it to make bookings.</p>
            </div>
        `;
        const alertDiv = document.createElement('div');
        alertDiv.innerHTML = successMessage;
        document.getElementById('customerRegistrationForm').insertAdjacentElement('beforebegin', alertDiv.firstChild);

        // Auto-scroll to show the success message
        alertDiv.firstChild.scrollIntoView({ behavior: 'smooth', block: 'nearest' });

        // Remove the alert after 30 seconds
        setTimeout(() => alertDiv.firstChild.remove(), 30000);
    } catch (error) {
        showError('customerRegistrationForm', `Failed to save customer information: ${error.message}`);
    } finally {
        hideLoading();
    }
}

async function handleCustomerForm(e) {
    e.preventDefault();
    try {
        showLoading();
        const formData = {
            firstname: document.getElementById('customerFirstName').value,
            lastname: document.getElementById('customerLastName').value,
            address: document.getElementById('customerAddress').value
        };

        const response = await fetch('/api/customers', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(formData)
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const result = await response.json();
        
        // Set the current customer ID
        currentCustomerId = result.customerid;
        
        // Reset form and show success message
        document.getElementById('customerForm').reset();
        const successMessage = `Customer created successfully! Your Customer ID is: <strong>${result.customerid}</strong>. Please save this ID for making bookings.`;
        const alertDiv = document.createElement('div');
        alertDiv.className = 'alert alert-success mt-3';
        alertDiv.innerHTML = successMessage;
        document.getElementById('customerForm').appendChild(alertDiv);

        // Auto-scroll to show the success message
        alertDiv.scrollIntoView({ behavior: 'smooth', block: 'nearest' });

        // Remove the alert after 30 seconds
        setTimeout(() => alertDiv.remove(), 30000);
        
        // Load customer bookings
        await loadCustomerBookings();
        
        // Switch to the My Bookings tab
        document.querySelector('a[href="#customerBookings"]').click();
    } catch (error) {
        showError('customerForm', `Failed to save customer information: ${error.message}`);
    } finally {
        hideLoading();
    }
}

function openBookingModal(room) {
    const modal = new bootstrap.Modal(document.getElementById('bookingModal'));
    const startDate = document.getElementById('startDate').value;
    const endDate = document.getElementById('endDate').value;
    
    // Set form values
    document.getElementById('modalRoomId').value = room.roomid;
    document.getElementById('modalStartDate').value = startDate;
    document.getElementById('modalEndDate').value = endDate;
    
    // Show booking details
    document.getElementById('bookingDetails').innerHTML = `
        <p><strong>Hotel:</strong> ${room.hotel_name}</p>
        <p><strong>Room:</strong> ${room.roomid}</p>
        <p><strong>Price:</strong> $${room.price}/night</p>
        <p><strong>Check-in:</strong> ${startDate}</p>
        <p><strong>Check-out:</strong> ${endDate}</p>
    `;
    modal.show();
}

async function handleBookingConfirmation() {
    try {
        showLoading();
        const roomId = document.getElementById('modalRoomId').value;
        const customerId = document.getElementById('bookingCustomerId').value;
        const startDate = document.getElementById('modalStartDate').value;
        const endDate = document.getElementById('modalEndDate').value;

        console.log('Booking confirmation data:', {
            roomId,
            customerId,
            startDate,
            endDate,
            isEmployee
        });

        if (!customerId) {
            throw new Error('Please enter a Customer ID');
        }

        // Set the current customer ID
        currentCustomerId = customerId;

        if (isEmployee) {
            const employeeId = document.getElementById('rentingEmployeeId').value;
            if (!employeeId) {
                throw new Error('Please enter an Employee ID');
            }
            await createRenting(roomId, customerId, employeeId, startDate, endDate);
        } else {
            await createBooking(roomId, customerId, startDate, endDate);
        }

        bootstrap.Modal.getInstance(document.getElementById('bookingModal')).hide();
        alert(`${isEmployee ? 'Renting' : 'Booking'} created successfully!`);
        
        // Load customer bookings after successful booking
        await loadCustomerBookings();
        
        // Refresh search results
        handleSearch(new Event('submit'));
        
        // Switch to the My Bookings tab
        document.querySelector('a[href="#customerBookings"]').click();
    } catch (error) {
        console.error('Error creating booking or renting:', {
            error: error.message,
            stack: error.stack
        });
        showError('bookingForm', `Failed to create ${isEmployee ? 'renting' : 'booking'}: ` + error.message);
    } finally {
        hideLoading();
    }
}

async function createBooking(roomId, customerId, startDate, endDate) {
    const body = {
        room_id: parseInt(roomId),
        customer_id: parseInt(customerId),
        start_date: startDate,
        end_date: endDate
    };
    console.log('Creating booking with:', body);
    
    const response = await fetch('/api/bookings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body)
    });

    if (!response.ok) {
        const errorData = await response.json().catch(() => null);
        console.error('Booking creation failed:', {
            status: response.status,
            statusText: response.statusText,
            error: errorData
        });
        throw new Error(errorData?.detail || `HTTP error! status: ${response.status}`);
    }
    return response.json();
}

async function createRenting(roomId, customerId, employeeId, startDate, endDate) {
    const response = await fetch('/api/rentings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            room_id: parseInt(roomId),
            customer_id: parseInt(customerId),
            employee_id: parseInt(employeeId),
            start_date: startDate,
            end_date: endDate
        })
    });

    if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
    }
    return response.json();
}

async function loadCustomerBookings() {
    if (!currentCustomerId) return;
    
    try {
        showLoading();
        const [bookingsResponse, rentingsResponse] = await Promise.all([
            fetch(`/api/customers/${currentCustomerId}/bookings`),
            fetch(`/api/customers/${currentCustomerId}/rentings`)
        ]);

        if (!bookingsResponse.ok || !rentingsResponse.ok) {
            throw new Error(`HTTP error! status: ${bookingsResponse.status} or ${rentingsResponse.status}`);
        }
        const bookings = await bookingsResponse.json();
        const rentings = await rentingsResponse.json();

        displayBookings(bookings);
        displayRentings(rentings);
    } catch (error) {
        console.error('Error loading customer bookings and rentings:', error);
        showError('bookingsList', 'Failed to load customer bookings and rentings: ' + error.message);
    } finally {
        hideLoading();
    }
}

function displayBookings(bookings) {
    const container = document.getElementById('bookingsList');
    container.innerHTML = bookings.length === 0 
        ? '<div class="alert alert-info">No bookings found.</div>'
        : bookings.map(booking => `
            <div class="card mb-3">
                <div class="card-body">
                    <h5 class="card-title">${booking.hotel_name}</h5>
                    <h6 class="card-subtitle mb-2 text-muted">Booking ID: ${booking.bookingid}</h6>
                    <div class="card-text">
                        <p><strong>Room Details:</strong></p>
                        <ul>
                            <li>Room Number: ${booking.roomid}</li>
                            <li>Room Type: ${booking.capacity} person(s), ${booking.view_type} view</li>
                            <li>Price: $${booking.price}/night</li>
                        </ul>
                        <p><strong>Stay Details:</strong></p>
                        <ul>
                            <li>Check-in: ${new Date(booking.startdate).toLocaleDateString()}</li>
                            <li>Check-out: ${new Date(booking.enddate).toLocaleDateString()}</li>
                            <li>Status: <span class="badge ${booking.status === 'Booked' ? 'bg-success' : 'bg-secondary'}">${booking.status}</span></li>
                        </ul>
                        <p><strong>Hotel Address:</strong> ${booking.hotel_address}</p>
                    </div>
                </div>
            </div>
        `).join('');
}

function displayRentings(rentings) {
    const container = document.getElementById('rentingsList');
    container.innerHTML = rentings.length === 0
        ? '<div class="alert alert-info">No rentings found.</div>'
        : rentings.map(renting => `
            <div class="card mb-3">
                <div class="card-body">
                    <h5 class="card-title">${renting.hotel_name}</h5>
                    <h6 class="card-subtitle mb-2 text-muted">Renting ID: ${renting.rentingid}</h6>
                    <div class="card-text">
                        <p><strong>Room Details:</strong></p>
                        <ul>
                            <li>Room Number: ${renting.roomid}</li>
                            <li>Room Type: ${renting.capacity} person(s), ${renting.view_type} view</li>
                            <li>Price: $${renting.price}/night</li>
                        </ul>
                        <p><strong>Stay Details:</strong></p>
                        <ul>
                            <li>Check-in: ${new Date(renting.startdate).toLocaleDateString()}</li>
                            <li>Check-out: ${new Date(renting.enddate).toLocaleDateString()}</li>
                            <li>Status: <span class="badge ${renting.status === 'Rented' ? 'bg-success' : 'bg-secondary'}">${renting.status}</span></li>
                        </ul>
                        <p><strong>Hotel Address:</strong> ${renting.hotel_address}</p>
                    </div>
                </div>
            </div>
        `).join('');
}

// Management functions for employees
async function updateCustomer() {
    if (!isEmployee) return;
    try {
        showLoading();
        const customerId = document.getElementById('customerId').value;
        const customerData = {
            firstname: document.getElementById('customerFirstName').value,
            lastname: document.getElementById('customerLastName').value,
            address: document.getElementById('customerAddress').value
        };

        const response = await fetch(`/api/customers/${customerId}`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(customerData)
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        if (response.ok) {
            alert('Customer updated successfully!');
        }
    } catch (error) {
        console.error('Error updating customer:', error);
        showError('manageCustomerForm', 'Failed to update customer: ' + error.message);
    } finally {
        hideLoading();
    }
}

async function deleteCustomer() {
    if (!isEmployee) return;
    if (!confirm('Are you sure you want to delete this customer?')) return;

    try {
        showLoading();
        const customerId = document.getElementById('customerId').value;
        const response = await fetch(`/api/customers/${customerId}`, {
            method: 'DELETE'
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        if (response.ok) {
            alert('Customer deleted successfully!');
            document.getElementById('manageCustomerForm').reset();
        }
    } catch (error) {
        console.error('Error deleting customer:', error);
        showError('manageCustomerForm', 'Failed to delete customer: ' + error.message);
    } finally {
        hideLoading();
    }
}

// Similar update/delete functions for employees, hotels, and rooms...
// These would follow the same pattern as the customer management functions
