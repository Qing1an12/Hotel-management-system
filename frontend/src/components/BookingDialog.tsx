import React, { useState } from 'react';
import {
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  Button,
  Grid,
  Typography,
  Alert,
} from '@mui/material';
import axios from 'axios';

interface BookingDialogProps {
  open: boolean;
  onClose: () => void;
  room: {
    roomid: number;
    hotelid: number;
    price: number;
    hotel_name: string;
  };
  startDate: Date | null;
  endDate: Date | null;
}

export const BookingDialog = ({ open, onClose, room, startDate, endDate }: BookingDialogProps) => {
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [address, setAddress] = useState('');
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);

  const handleSubmit = async () => {
    try {
      setError('');
      // Create customer first
      const customerResponse = await axios.post('http://localhost:8000/api/customers', {
        firstname: firstName,
        lastname: lastName,
        address: address
      });

      const customerId = customerResponse.data.customerid;

      // Create booking
      await axios.post('http://localhost:8000/api/bookings', {
        room_id: room.roomid,
        customer_id: customerId,
        start_date: startDate?.toISOString().split('T')[0],
        end_date: endDate?.toISOString().split('T')[0]
      });

      setSuccess(true);
      setTimeout(() => {
        onClose();
        setSuccess(false);
        setFirstName('');
        setLastName('');
        setAddress('');
      }, 2000);
    } catch (error: any) {
      setError(error.response?.data?.detail || 'Failed to create booking');
    }
  };

  return (
    <Dialog open={open} onClose={onClose} maxWidth="sm" fullWidth>
      <DialogTitle>Book Room at {room.hotel_name}</DialogTitle>
      <DialogContent>
        <Grid container spacing={2} sx={{ mt: 1 }}>
          <Grid item xs={12}>
            <Typography variant="body1" gutterBottom>
              Price: ${room.price}/night
            </Typography>
            <Typography variant="body1" gutterBottom>
              Check-in: {startDate?.toLocaleDateString()}
            </Typography>
            <Typography variant="body1" gutterBottom>
              Check-out: {endDate?.toLocaleDateString()}
            </Typography>
          </Grid>
          {error && (
            <Grid item xs={12}>
              <Alert severity="error">{error}</Alert>
            </Grid>
          )}
          {success && (
            <Grid item xs={12}>
              <Alert severity="success">Booking successful!</Alert>
            </Grid>
          )}
          <Grid item xs={12} sm={6}>
            <TextField
              fullWidth
              label="First Name"
              value={firstName}
              onChange={(e) => setFirstName(e.target.value)}
              required
            />
          </Grid>
          <Grid item xs={12} sm={6}>
            <TextField
              fullWidth
              label="Last Name"
              value={lastName}
              onChange={(e) => setLastName(e.target.value)}
              required
            />
          </Grid>
          <Grid item xs={12}>
            <TextField
              fullWidth
              label="Address"
              value={address}
              onChange={(e) => setAddress(e.target.value)}
              required
              multiline
              rows={2}
            />
          </Grid>
        </Grid>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose}>Cancel</Button>
        <Button 
          onClick={handleSubmit}
          variant="contained" 
          disabled={!firstName || !lastName || !address || !startDate || !endDate}
        >
          Book Now
        </Button>
      </DialogActions>
    </Dialog>
  );
};
