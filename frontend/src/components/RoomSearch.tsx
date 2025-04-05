import React, { useState } from 'react';
import {
  Paper,
  Grid,
  TextField,
  Button,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  Card,
  CardContent,
  Typography,
  Box,
} from '@mui/material';
import { DatePicker } from '@mui/x-date-pickers/DatePicker';
import axios from 'axios';
import { BookingDialog } from './BookingDialog';

interface Room {
  roomid: number;
  hotelid: number;
  price: number;
  view: string;
  amenities: string[];
  capacity: number;
  hotel_name: string;
  chain_name: string;
}

const RoomSearch = () => {
  const [startDate, setStartDate] = useState<Date | null>(null);
  const [endDate, setEndDate] = useState<Date | null>(null);
  const [capacity, setCapacity] = useState('');
  const [area, setArea] = useState('');
  const [hotelChain, setHotelChain] = useState('');
  const [hotelCategory, setHotelCategory] = useState('');
  const [maxPrice, setMaxPrice] = useState('');
  const [rooms, setRooms] = useState<Room[]>([]);
  const [selectedRoom, setSelectedRoom] = useState<Room | null>(null);
  const [bookingDialogOpen, setBookingDialogOpen] = useState(false);

  const handleSearch = async () => {
    try {
      const response = await axios.get('http://localhost:8000/api/rooms/available', {
        params: {
          start_date: startDate?.toISOString().split('T')[0],
          end_date: endDate?.toISOString().split('T')[0],
          capacity: capacity || undefined,
          area: area || undefined,
          hotel_chain: hotelChain || undefined,
          hotel_category: hotelCategory || undefined,
          max_price: maxPrice || undefined,
        },
      });
      setRooms(response.data);
    } catch (error) {
      console.error('Error fetching rooms:', error);
    }
  };

  const handleBookClick = (room: Room) => {
    setSelectedRoom(room);
    setBookingDialogOpen(true);
  };

  return (
    <>
      <Paper sx={{ p: 3, mb: 3 }}>
        <Grid container spacing={3}>
          <Grid item xs={12} sm={6} md={3}>
            <DatePicker
              label="Check-in Date"
              value={startDate}
              onChange={(newValue) => setStartDate(newValue)}
              slotProps={{
                textField: {
                  fullWidth: true,
                  variant: "outlined"
                }
              }}
            />
          </Grid>
          <Grid item xs={12} sm={6} md={3}>
            <DatePicker
              label="Check-out Date"
              value={endDate}
              onChange={(newValue) => setEndDate(newValue)}
              slotProps={{
                textField: {
                  fullWidth: true,
                  variant: "outlined"
                }
              }}
            />
          </Grid>
          <Grid item xs={12} sm={6} md={3}>
            <FormControl fullWidth>
              <InputLabel>Room Capacity</InputLabel>
              <Select
                value={capacity}
                label="Room Capacity"
                onChange={(e) => setCapacity(e.target.value)}
              >
                <MenuItem value={1}>Single</MenuItem>
                <MenuItem value={2}>Double</MenuItem>
                <MenuItem value={3}>Triple</MenuItem>
                <MenuItem value={4}>Quad</MenuItem>
              </Select>
            </FormControl>
          </Grid>
          <Grid item xs={12} sm={6} md={3}>
            <FormControl fullWidth>
              <InputLabel>View</InputLabel>
              <Select
                value={area}
                label="View"
                onChange={(e) => setArea(e.target.value)}
              >
                <MenuItem value="sea">Sea View</MenuItem>
                <MenuItem value="mountain">Mountain View</MenuItem>
              </Select>
            </FormControl>
          </Grid>
          <Grid item xs={12} sm={6} md={4}>
            <TextField
              fullWidth
              label="Hotel Chain"
              value={hotelChain}
              onChange={(e) => setHotelChain(e.target.value)}
            />
          </Grid>
          <Grid item xs={12} sm={6} md={4}>
            <FormControl fullWidth>
              <InputLabel>Hotel Category</InputLabel>
              <Select
                value={hotelCategory}
                label="Hotel Category"
                onChange={(e) => setHotelCategory(e.target.value)}
              >
                {[1, 2, 3, 4, 5].map((stars) => (
                  <MenuItem key={stars} value={stars}>{`${stars} Star`}</MenuItem>
                ))}
              </Select>
            </FormControl>
          </Grid>
          <Grid item xs={12} sm={6} md={4}>
            <TextField
              fullWidth
              label="Max Price"
              type="number"
              value={maxPrice}
              onChange={(e) => setMaxPrice(e.target.value)}
            />
          </Grid>
          <Grid item xs={12}>
            <Button
              variant="contained"
              color="primary"
              onClick={handleSearch}
              fullWidth
            >
              Search Rooms
            </Button>
          </Grid>
        </Grid>
      </Paper>

      <Grid container spacing={3}>
        {rooms.map((room) => (
          <Grid item xs={12} sm={6} md={4} key={room.roomid}>
            <Card>
              <CardContent>
                <Typography variant="h6" gutterBottom>
                  {room.hotel_name}
                </Typography>
                <Typography color="textSecondary">
                  {room.chain_name}
                </Typography>
                <Box sx={{ mt: 2 }}>
                  <Typography>Price: ${room.price}/night</Typography>
                  <Typography>View: {room.view}</Typography>
                  <Typography>Capacity: {room.capacity} person(s)</Typography>
                  <Typography>Amenities: {room.amenities.join(', ')}</Typography>
                </Box>
                <Button
                  variant="contained"
                  color="primary"
                  fullWidth
                  sx={{ mt: 2 }}
                  onClick={() => handleBookClick(room)}
                >
                  Book Now
                </Button>
              </CardContent>
            </Card>
          </Grid>
        ))}
      </Grid>

      {selectedRoom && (
        <BookingDialog
          open={bookingDialogOpen}
          onClose={() => setBookingDialogOpen(false)}
          room={selectedRoom}
          startDate={startDate}
          endDate={endDate}
        />
      )}
    </>
  );
};

export default RoomSearch;
