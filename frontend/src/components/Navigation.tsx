import React from 'react';
import {
  AppBar,
  Toolbar,
  Typography,
  Button,
  Box,
} from '@mui/material';
import { Link as RouterLink } from 'react-router-dom';

const Navigation = () => {
  return (
    <AppBar position="static">
      <Toolbar>
        <Typography variant="h6" component="div" sx={{ flexGrow: 1 }}>
          Hotel Chains
        </Typography>
        <Box>
          <Button color="inherit" component={RouterLink} to="/">
            Search Rooms
          </Button>
          <Button color="inherit" component={RouterLink} to="/bookings">
            My Bookings
          </Button>
          <Button color="inherit">
            Login
          </Button>
        </Box>
      </Toolbar>
    </AppBar>
  );
};

export default Navigation;
