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
            document.getElementById('employeeFields').style.display = isEmployee ? 'block' : 'none';
            document.getElementById('customerFields').style.display = !isEmployee ? 'block' : 'none';
        });
    });

    // Load initial data
    loadHotelChains();

    // Set up event listeners
    document.getElementById('searchForm').addEventListener('submit', handleSearch);
    document.getElementById('customerForm').addEventListener('submit', handleCustomerForm);
    document.getElementById('confirmBooking').addEventListener('click', handleBookingConfirmation);
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
        const response = await fetch(`/api/rooms/available?${params}`);
        
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

function displaySearchResults(rooms) {
    const resultsDiv = document.getElementById('searchResults');
    resultsDiv.innerHTML = '';

    if (!Array.isArray(rooms) || rooms.length === 0) {
        const noResults = document.createElement('div');
        noResults.className = 'alert alert-info';
        noResults.textContent = 'No rooms available for the selected criteria.';
        resultsDiv.appendChild(noResults);
        return;
    }

    const container = document.createElement('div');
    container.className = 'row g-4';

    rooms.forEach(room => {
        const col = document.createElement('div');
        col.className = 'col-md-6 col-lg-4';

        const card = document.createElement('div');
        card.className = 'card h-100 room-card';

        const cardBody = document.createElement('div');
        cardBody.className = 'card-body';

        const title = document.createElement('h5');
        title.className = 'card-title';
        title.textContent = `${room.hotel_name} - Room ${room.roomid}`;

        const chainName = document.createElement('h6');
        chainName.className = 'card-subtitle mb-2 text-muted';
        chainName.textContent = room.chain_name;

        const details = document.createElement('ul');
        details.className = 'list-unstyled';
        details.innerHTML = `
            <li><strong>Price:</strong> $${room.price}/night</li>
            <li><strong>Capacity:</strong> ${room.capacity} ${room.capacity === 1 ? 'person' : 'people'}</li>
            <li><strong>Area:</strong> ${room.area}</li>
        `;

        const bookButton = document.createElement('button');
        bookButton.className = 'btn btn-primary mt-3';
        bookButton.textContent = isEmployee ? 'Create Renting' : 'Book Now';
        bookButton.onclick = () => openBookingModal(room);

        cardBody.appendChild(title);
        cardBody.appendChild(chainName);
        cardBody.appendChild(details);
        cardBody.appendChild(bookButton);
        card.appendChild(cardBody);
        col.appendChild(card);
        container.appendChild(col);
    });

    resultsDiv.appendChild(container);
}

async function handleCustomerForm(e) {
    e.preventDefault();
    clearError('customerForm');

    const firstname = document.getElementById('firstname').value.trim();
    const lastname = document.getElementById('lastname').value.trim();
    const address = document.getElementById('address').value.trim();

    // Validate input
    if (!firstname || !lastname || !address) {
        showError('customerForm', 'All fields are required');
        return;
    }

    try {
        showLoading();
        const customerData = { firstname, lastname, address };
        
        console.log('Creating customer:', customerData);
        const response = await fetch('/api/customers', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(customerData)
        });

        const data = await response.json();
        
        if (!response.ok) {
            throw new Error(data.detail || 'Failed to create customer');
        }

        console.log('Customer created:', data);
        currentCustomerId = data.customerid;
        
        // Clear form and show success message
        document.getElementById('customerForm').reset();
        showError('customerForm', 'Customer information saved successfully!');
        
        // Update UI to show customer is logged in
        document.getElementById('customerInfo').style.display = 'none';
        document.getElementById('bookingSection').style.display = 'block';
        
        // Load customer's bookings
        await loadCustomerBookings();
    } catch (error) {
        console.error('Error creating customer:', error);
        showError('customerForm', `Failed to save customer information: ${error.message}`);
    } finally {
        hideLoading();
    }
}

function openBookingModal(room) {
    const modal = new bootstrap.Modal(document.getElementById('bookingModal'));
    document.getElementById('modalRoomId').value = room.roomid;
    document.getElementById('bookingDetails').innerHTML = `
        <p><strong>Hotel:</strong> ${room.hotel_name}</p>
        <p><strong>Room:</strong> ${room.roomid}</p>
        <p><strong>Price:</strong> $${room.price}/night</p>
    `;
    modal.show();
}

async function handleBookingConfirmation() {
    try {
        showLoading();
        const roomId = document.getElementById('modalRoomId').value;
        const customerId = document.getElementById('bookingCustomerId').value;
        const startDate = document.getElementById('startDate').value;
        const endDate = document.getElementById('endDate').value;

        if (isEmployee) {
            const employeeId = document.getElementById('rentingEmployeeId').value;
            await createRenting(roomId, customerId, employeeId, startDate, endDate);
        } else {
            await createBooking(roomId, customerId, startDate, endDate);
        }

        bootstrap.Modal.getInstance(document.getElementById('bookingModal')).hide();
        alert(`${isEmployee ? 'Renting' : 'Booking'} created successfully!`);
        handleSearch(new Event('submit')); // Refresh search results
    } catch (error) {
        console.error('Error creating booking or renting:', error);
        showError('bookingForm', `Failed to create ${isEmployee ? 'renting' : 'booking'}: ` + error.message);
    } finally {
        hideLoading();
    }
}

async function createBooking(roomId, customerId, startDate, endDate) {
    const response = await fetch('/api/bookings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            room_id: parseInt(roomId),
            customer_id: parseInt(customerId),
            start_date: startDate,
            end_date: endDate
        })
    });

    if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
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
                    <h6 class="card-subtitle mb-2 text-muted">Booking ID: ${booking.bookingid}</h6>
                    <p class="card-text">
                        Room: ${booking.roomid}<br>
                        Dates: ${new Date(booking.start_date).toLocaleDateString()} - 
                              ${new Date(booking.end_date).toLocaleDateString()}
                    </p>
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
                    <h6 class="card-subtitle mb-2 text-muted">Renting ID: ${renting.rentingid}</h6>
                    <p class="card-text">
                        Room: ${renting.roomid}<br>
                        Status: ${renting.status}<br>
                        Dates: ${new Date(renting.start_date).toLocaleDateString()} - 
                              ${new Date(renting.end_date).toLocaleDateString()}
                    </p>
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
