import React, { useState, useEffect, createContext, useContext } from 'react';
import { initializeApp } from 'firebase/app';
import { getAuth, signInAnonymously, signInWithCustomToken, onAuthStateChanged } from 'firebase/auth';
import { getFirestore, collection, query, onSnapshot, addDoc, doc, updateDoc, deleteDoc, getDoc, getDocs } from 'firebase/firestore'; // Added getDocs here

// Global variables provided by the Canvas environment
// Note: When running in a local VS Code environment, __app_id and __firebase_config
// will not be available. You will need to define these manually or set up
// environment variables. For local testing, you can use placeholder values.
const appId = typeof __app_id !== 'undefined' ? __app_id : 'default-app-id'; // Use a default appId for local dev
const firebaseConfig = typeof __firebase_config !== 'undefined' ? JSON.parse(__firebase_config) : {
  // IMPORTANT: Replace these with your actual Firebase project configuration for local development.
  // You can find this in your Firebase project settings (Project settings -> General -> Your apps -> Firebase SDK snippet -> Config)
  apiKey: "YOUR_API_KEY", // <--- REPLACE THIS
  authDomain: "YOUR_AUTH_DOMAIN", // <--- REPLACE THIS
  projectId: "YOUR_PROJECT_ID", // <--- REPLACE THIS
  storageBucket: "YOUR_STORAGE_BUCKET", // <--- REPLACE THIS
  messagingSenderId: "YOUR_MESSAGING_SENDER_ID", // <--- REPLACE THIS
  appId: "YOUR_APP_ID", // <--- REPLACE THIS
  // measurementId: "YOUR_MEASUREMENT_ID" // Optional, if you use Google Analytics
};

// Create a context for Firebase and User data
const AppContext = createContext(null);

// Custom Modal Component (replaces alert/confirm)
const Modal = ({ message, onConfirm, onCancel, showCancel = false }) => {
  if (!message) return null;

  return (
    <div className="fixed inset-0 bg-gray-600 bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-lg shadow-xl p-6 max-w-sm w-full text-center">
        <p className="text-lg font-semibold mb-6">{message}</p>
        <div className="flex justify-center space-x-4">
          <button
            onClick={onConfirm}
            className="px-6 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-opacity-50 transition duration-200"
          >
            OK
          </button>
          {showCancel && (
            <button
              onClick={onCancel}
              className="px-6 py-2 bg-gray-300 text-gray-800 rounded-md hover:bg-gray-400 focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-opacity-50 transition duration-200"
            >
              Cancel
            </button>
          )}
        </div>
      </div>
    </div>
  );
};

// Main App Component
const App = () => {
  const [db, setDb] = useState(null);
  const [auth, setAuth] = useState(null);
  const [userId, setUserId] = useState(null);
  const [loading, setLoading] = useState(true);
  const [currentView, setCurrentView] = useState('customerList'); // 'customerList' or 'customerDetail'
  const [selectedCustomer, setSelectedCustomer] = useState(null);
  const [modalMessage, setModalMessage] = useState(null);
  const [modalConfirmAction, setModalConfirmAction] = useState(null);
  const [modalShowCancel, setModalShowCancel] = useState(false);
  const [modalCancelAction, setModalCancelAction] = useState(null); // State for cancel action

  // Function to show custom modal
  const showModal = (message, onConfirm, showCancel = false, onCancel = null) => {
    setModalMessage(message);
    setModalConfirmAction(() => onConfirm); // Use a function to store the callback
    setModalShowCancel(showCancel);
    if (showCancel && onCancel) {
      setModalCancelAction(() => onCancel); // Set cancel action for Cancel button
    } else {
      setModalCancelAction(null); // Clear cancel action if not needed
    }
  };

  const closeModal = () => {
    setModalMessage(null);
    setModalConfirmAction(null);
    setModalShowCancel(false);
    setModalCancelAction(null);
  };

  const handleModalConfirm = () => {
    if (modalConfirmAction) {
      modalConfirmAction();
    }
    closeModal();
  };

  const handleModalCancel = () => {
    if (modalCancelAction) { // Execute cancel action if it exists
      modalCancelAction();
    }
    closeModal();
  };


  // Initialize Firebase and set up auth listener
  useEffect(() => {
    try {
      const app = initializeApp(firebaseConfig);
      const authInstance = getAuth(app);
      const firestoreInstance = getFirestore(app);
      setAuth(authInstance);
      setDb(firestoreInstance);

      // Listen for auth state changes
      const unsubscribe = onAuthStateChanged(authInstance, async (user) => {
        if (user) {
          setUserId(user.uid);
        } else {
          // Sign in anonymously if no user is logged in and no custom token is provided
          // For local VS Code, __initial_auth_token will be undefined, so it will sign in anonymously.
          if (typeof __initial_auth_token === 'undefined') {
            await signInAnonymously(authInstance);
          }
        }
        setLoading(false);
      });

      // Use custom token if provided by the Canvas environment (not applicable for local VS Code)
      if (typeof __initial_auth_token !== 'undefined' && authInstance) {
        signInWithCustomToken(authInstance, __initial_auth_token)
          .then(() => {
            console.log("Signed in with custom token.");
          })
          .catch((error) => {
            console.error("Error signing in with custom token:", error);
            showModal(`Authentication Error: ${error.message}`, closeModal);
            setLoading(false);
          });
      }

      return () => unsubscribe(); // Cleanup auth listener
    } catch (error) {
      console.error("Failed to initialize Firebase:", error);
      showModal(`Firebase Initialization Error: ${error.message}`, closeModal);
      setLoading(false);
    }
  }, []); // Empty dependency array means this runs once on mount

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen bg-gray-100">
        <div className="text-xl font-semibold text-gray-700">Loading Tallykhata App...</div>
      </div>
    );
  }

  return (
    <AppContext.Provider value={{ db, auth, userId, showModal }}>
      <div className="min-h-screen bg-gray-100 font-sans text-gray-800 flex flex-col items-center py-8 px-4 sm:px-6 lg:px-8">
        <Modal
          message={modalMessage}
          onConfirm={handleModalConfirm}
          onCancel={handleModalCancel}
          showCancel={modalShowCancel}
        />

        <header className="w-full max-w-4xl bg-white shadow-md rounded-lg p-6 mb-8 text-center">
          <h1 className="text-3xl font-bold text-blue-700 mb-2">টালিখাতা অ্যাপ</h1>
          <p className="text-gray-600">আপনার ব্যবসার হিসাব রাখুন সহজে</p>
          {userId && (
            <p className="text-sm text-gray-500 mt-2">ব্যবহারকারী আইডি: <span className="font-mono break-all">{userId}</span></p>
          )}
        </header>

        <main className="w-full max-w-4xl bg-white shadow-md rounded-lg p-6">
          {currentView === 'customerList' ? (
            <CustomerList
              onSelectCustomer={(customer) => {
                setSelectedCustomer(customer);
                setCurrentView('customerDetail');
              }}
            />
          ) : (
            <CustomerDetail
              customer={selectedCustomer}
              onBack={() => {
                setSelectedCustomer(null);
                setCurrentView('customerList');
              }}
            />
          )}
        </main>
      </div>
    </AppContext.Provider>
  );
};

// Customer List Component
const CustomerList = ({ onSelectCustomer }) => {
  const { db, userId, showModal } = useContext(AppContext);
  const [customers, setCustomers] = useState([]);
  const [newCustomerName, setNewCustomerName] = useState('');
  const [loadingCustomers, setLoadingCustomers] = useState(true);

  // Fetch customers in real-time
  useEffect(() => {
    if (!db || !userId) return;

    setLoadingCustomers(true);
    // Firestore path for customers: artifacts/{appId}/users/{userId}/customers
    const customersColRef = collection(db, `artifacts/${appId}/users/${userId}/customers`);
    const q = query(customersColRef);

    const unsubscribe = onSnapshot(q, (snapshot) => {
      const customersData = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));
      // Sort customers by name for consistent display
      customersData.sort((a, b) => a.name.localeCompare(b.name));
      setCustomers(customersData);
      setLoadingCustomers(false);
    }, (error) => {
      console.error("Error fetching customers:", error);
      showModal(`গ্রাহকদের ডেটা লোড করতে সমস্যা হয়েছে: ${error.message}`, () => {});
      setLoadingCustomers(false);
    });

    return () => unsubscribe(); // Cleanup listener when component unmounts or dependencies change
  }, [db, userId, showModal]); // Dependencies for useEffect

  // Add a new customer
  const handleAddCustomer = async (e) => {
    e.preventDefault(); // Prevent default form submission behavior
    if (!newCustomerName.trim() || !db || !userId) {
      showModal("গ্রাহকের নাম লিখুন।", () => {});
      return;
    }

    try {
      setLoadingCustomers(true);
      await addDoc(collection(db, `artifacts/${appId}/users/${userId}/customers`), {
        name: newCustomerName.trim(),
        balance: 0, // Initial balance for a new customer
        createdAt: new Date(), // Timestamp for creation
      });
      setNewCustomerName(''); // Clear input field after adding
      showModal("গ্রাহক সফলভাবে যোগ করা হয়েছে!", () => {});
    } catch (error) {
      console.error("Error adding customer:", error);
      showModal(`গ্রাহক যোগ করতে সমস্যা হয়েছে: ${error.message}`, () => {});
    } finally {
      setLoadingCustomers(false);
    }
  };

  const handleDeleteCustomer = (customerId, customerName) => {
    showModal(
      `আপনি কি নিশ্চিত যে আপনি "${customerName}" গ্রাহককে মুছে ফেলতে চান? এই গ্রাহকের সমস্ত লেনদেনও মুছে যাবে।`,
      async () => { // Confirm action
        try {
          setLoadingCustomers(true);
          // First, delete all transactions associated with this customer
          const transactionsColRef = collection(db, `artifacts/${appId}/users/${userId}/customers/${customerId}/transactions`);
          const q = query(transactionsColRef);
          const snapshot = await getDocs(q); // Use getDocs to fetch all documents once
          const deletePromises = snapshot.docs.map(doc => deleteDoc(doc.ref));
          await Promise.all(deletePromises); // Wait for all transaction deletions to complete

          // Then, delete the customer document itself
          await deleteDoc(doc(db, `artifacts/${appId}/users/${userId}/customers`, customerId));
          showModal("গ্রাহক সফলভাবে মুছে ফেলা হয়েছে!", () => {});
        } catch (error) {
          console.error("Error deleting customer:", error);
          showModal(`গ্রাহক মুছে ফেলতে সমস্যা হয়েছে: ${error.message}`, () => {});
        } finally {
          setLoadingCustomers(false);
        }
      },
      true, // Show cancel button
      () => {} // Cancel action (do nothing, just close modal)
    );
  };


  return (
    <div className="p-4">
      <h2 className="text-2xl font-semibold text-blue-600 mb-6">গ্রাহকদের তালিকা</h2>

      <form onSubmit={handleAddCustomer} className="mb-8 flex flex-col sm:flex-row gap-4">
        <input
          type="text"
          value={newCustomerName}
          onChange={(e) => setNewCustomerName(e.target.value)}
          placeholder="নতুন গ্রাহকের নাম লিখুন"
          className="flex-grow p-3 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500 shadow-sm"
          aria-label="New customer name"
        />
        <button
          type="submit"
          className="px-6 py-3 bg-green-600 text-white rounded-md hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-green-500 focus:ring-opacity-50 transition duration-200 shadow-md"
        >
          গ্রাহক যোগ করুন
        </button>
      </form>

      {loadingCustomers ? (
        <div className="text-center text-gray-600">গ্রাহকদের ডেটা লোড হচ্ছে...</div>
      ) : customers.length === 0 ? (
        <div className="text-center text-gray-600">কোনো গ্রাহক নেই। নতুন গ্রাহক যোগ করুন।</div>
      ) : (
        <ul className="space-y-4">
          {customers.map((customer) => (
            <li
              key={customer.id}
              className="bg-white p-4 rounded-lg shadow-sm flex flex-col sm:flex-row items-start sm:items-center justify-between border border-gray-200 hover:shadow-md transition duration-200"
            >
              <div
                className="flex-grow cursor-pointer"
                onClick={() => onSelectCustomer(customer)}
              >
                <h3 className="text-xl font-medium text-gray-900">{customer.name}</h3>
                <p className={`text-lg font-bold ${customer.balance >= 0 ? 'text-green-600' : 'text-red-600'}`}>
                  ব্যালেন্স: {customer.balance >= 0 ? 'জমা' : 'বাকি'} {Math.abs(customer.balance).toFixed(2)} টাকা
                </p>
              </div>
              <button
                onClick={() => handleDeleteCustomer(customer.id, customer.name)}
                className="mt-3 sm:mt-0 px-4 py-2 bg-red-500 text-white rounded-md hover:bg-red-600 focus:outline-none focus:ring-2 focus:ring-red-500 focus:ring-opacity-50 transition duration-200 shadow-sm"
                aria-label={`Delete ${customer.name}`}
              >
                মুছে ফেলুন
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
};

// Customer Detail Component
const CustomerDetail = ({ customer, onBack }) => {
  const { db, userId, showModal } = useContext(AppContext);
  const [transactions, setTransactions] = useState([]);
  const [amount, setAmount] = useState('');
  const [type, setType] = useState('got'); // 'got' (পেলেন) or 'gave' (দিলেন)
  const [description, setDescription] = useState('');
  const [loadingTransactions, setLoadingTransactions] = useState(true);
  const [currentCustomerBalance, setCurrentCustomerBalance] = useState(customer.balance || 0);

  // Fetch transactions in real-time
  useEffect(() => {
    if (!db || !userId || !customer?.id) return;

    setLoadingTransactions(true);
    // Firestore path for transactions: artifacts/{appId}/users/{userId}/customers/{customerId}/transactions
    const transactionsColRef = collection(db, `artifacts/${appId}/users/${userId}/customers/${customer.id}/transactions`);
    const q = query(transactionsColRef);

    const unsubscribe = onSnapshot(q, (snapshot) => {
      const transactionsData = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));
      // Sort transactions by timestamp descending (most recent first)
      transactionsData.sort((a, b) => b.timestamp.toDate() - a.timestamp.toDate());
      setTransactions(transactionsData);
      setLoadingTransactions(false);
    }, (error) => {
      console.error("Error fetching transactions:", error);
      showModal(`লেনদেনের ডেটা লোড করতে সমস্যা হয়েছে: ${error.message}`, () => {});
      setLoadingTransactions(false);
    });

    // Also listen to the customer document for real-time balance updates
    const customerDocRef = doc(db, `artifacts/${appId}/users/${userId}/customers`, customer.id);
    const unsubscribeCustomer = onSnapshot(customerDocRef, (docSnap) => {
      if (docSnap.exists()) {
        setCurrentCustomerBalance(docSnap.data().balance || 0);
      } else {
        // If customer document no longer exists (e.g., deleted by another user/instance)
        // Optionally, navigate back to customer list or show an error
        console.warn("Selected customer document no longer exists.");
        // onBack(); // Could automatically go back if customer is deleted
      }
    }, (error) => {
      console.error("Error fetching customer balance:", error);
      // showModal(`গ্রাহকের ব্যালেন্স লোড করতে সমস্যা হয়েছে: ${error.message}`, () => {});
    });


    return () => {
      unsubscribe(); // Cleanup transaction listener
      unsubscribeCustomer(); // Cleanup customer balance listener
    };
  }, [db, userId, customer?.id, showModal]); // Dependencies for useEffect

  // Add a new transaction
  const handleAddTransaction = async (e) => {
    e.preventDefault(); // Prevent default form submission
    const parsedAmount = parseFloat(amount);

    if (isNaN(parsedAmount) || parsedAmount <= 0 || !db || !userId || !customer?.id) {
      showModal("বৈধ টাকার পরিমাণ লিখুন।", () => {});
      return;
    }

    try {
      setLoadingTransactions(true);
      // Add transaction document to the subcollection
      await addDoc(collection(db, `artifacts/${appId}/users/${userId}/customers/${customer.id}/transactions`), {
        amount: parsedAmount,
        type: type, // 'got' or 'gave'
        description: description.trim(),
        timestamp: new Date(), // Use server timestamp for consistency if possible, but new Date() works locally
      });

      // Update customer's main balance in their document
      const customerDocRef = doc(db, `artifacts/${appId}/users/${userId}/customers`, customer.id);
      const currentBalance = currentCustomerBalance; // Get the most recent balance from state
      let newBalance;
      if (type === 'got') { // If money was received (পেলেন), add to balance
        newBalance = currentBalance + parsedAmount;
      } else { // If money was given (দিলেন), subtract from balance
        newBalance = currentBalance - parsedAmount;
      }

      await updateDoc(customerDocRef, {
        balance: newBalance,
      });

      setAmount(''); // Clear amount input
      setDescription(''); // Clear description input
      showModal("লেনদেন সফলভাবে যোগ করা হয়েছে!", () => {});
    } catch (error) {
      console.error("Error adding transaction:", error);
      showModal(`লেনদেন যোগ করতে সমস্যা হয়েছে: ${error.message}`, () => {});
    } finally {
      setLoadingTransactions(false);
    }
  };

  const handleDeleteTransaction = (transactionId, transactionAmount, transactionType) => {
    showModal(
      `আপনি কি নিশ্চিত যে আপনি এই লেনদেনটি মুছে ফেলতে চান?`,
      async () => { // Confirm action
        try {
          setLoadingTransactions(true);
          // Delete the transaction document
          await deleteDoc(doc(db, `artifacts/${appId}/users/${userId}/customers/${customer.id}/transactions`, transactionId));

          // Revert the customer's balance by adjusting it based on the deleted transaction
          const customerDocRef = doc(db, `artifacts/${appId}/users/${userId}/customers`, customer.id);
          const currentBalance = currentCustomerBalance; // Get the most recent balance from state
          let newBalance;
          if (transactionType === 'got') { // If the deleted transaction was 'got', subtract its amount from balance
            newBalance = currentBalance - transactionAmount;
          } else { // If the deleted transaction was 'gave', add its amount back to balance
            newBalance = currentBalance + transactionAmount;
          }

          await updateDoc(customerDocRef, {
            balance: newBalance,
          });
          showModal("লেনদেন সফলভাবে মুছে ফেলা হয়েছে!", () => {});
        } catch (error) {
          console.error("Error deleting transaction:", error);
          showModal(`লেনদেন মুছে ফেলতে সমস্যা হয়েছে: ${error.message}`, () => {});
        } finally {
          setLoadingTransactions(false);
        }
      },
      true, // Show cancel button
      () => {} // Cancel action (do nothing, just close modal)
    );
  };


  return (
    <div className="p-4">
      <button
        onClick={onBack}
        className="mb-6 px-4 py-2 bg-gray-200 text-gray-800 rounded-md hover:bg-gray-300 focus:outline-none focus:ring-2 focus:ring-gray-400 focus:ring-opacity-50 transition duration-200 shadow-sm flex items-center"
      >
        <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 mr-2" viewBox="0 0 20 20" fill="currentColor">
          <path fillRule="evenodd" d="M12.707 5.293a1 1 0 010 1.414L9.414 10l3.293 3.293a1 1 0 01-1.414 1.414l-4-4a1 1 0 010-1.414l4-4a1 1 0 011.414 0z" clipRule="evenodd" />
        </svg>
        গ্রাহকদের তালিকায় ফিরে যান
      </button>

      <h2 className="text-2xl font-semibold text-blue-600 mb-2">{customer.name}</h2>
      <p className={`text-xl font-bold mb-6 ${currentCustomerBalance >= 0 ? 'text-green-700' : 'text-red-700'}`}>
        বর্তমান ব্যালেন্স: {currentCustomerBalance >= 0 ? 'জমা' : 'বাকি'} {Math.abs(currentCustomerBalance).toFixed(2)} টাকা
      </p>

      <form onSubmit={handleAddTransaction} className="mb-8 p-6 bg-blue-50 rounded-lg shadow-inner">
        <h3 className="text-xl font-medium text-blue-700 mb-4">নতুন লেনদেন যোগ করুন</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
          <div>
            <label htmlFor="amount" className="block text-sm font-medium text-gray-700 mb-1">টাকার পরিমাণ</label>
            <input
              type="number"
              id="amount"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              placeholder="উদাহরণ: ৫০০"
              className="w-full p-3 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500 shadow-sm"
              step="0.01"
              aria-label="Transaction amount"
            />
          </div>
          <div>
            <label htmlFor="type" className="block text-sm font-medium text-gray-700 mb-1">লেনদেনের প্রকার</label>
            <select
              id="type"
              value={type}
              onChange={(e) => setType(e.target.value)}
              className="w-full p-3 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500 shadow-sm bg-white"
              aria-label="Transaction type"
            >
              <option value="got">পেলেন (Got)</option>
              <option value="gave">দিলেন (Gave)</option>
            </select>
          </div>
        </div>
        <div className="mb-6">
          <label htmlFor="description" className="block text-sm font-medium text-gray-700 mb-1">বিবরণ (ঐচ্ছিক)</label>
          <input
            type="text"
            id="description"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            placeholder="উদাহরণ: পণ্য কেনা, নগদ টাকা"
            className="w-full p-3 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500 shadow-sm"
            aria-label="Transaction description"
          />
        </div>
        <button
          type="submit"
          className="w-full px-6 py-3 bg-blue-600 text-white rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-opacity-50 transition duration-200 shadow-md"
        >
          লেনদেন যোগ করুন
        </button>
      </form>

      <h3 className="text-xl font-medium text-blue-700 mb-4">লেনদেনের ইতিহাস</h3>
      {loadingTransactions ? (
        <div className="text-center text-gray-600">লেনদেনের ডেটা লোড হচ্ছে...</div>
      ) : transactions.length === 0 ? (
        <div className="text-center text-gray-600">এই গ্রাহকের কোনো লেনদেন নেই।</div>
      ) : (
        <ul className="space-y-3">
          {transactions.map((transaction) => (
            <li
              key={transaction.id}
              className="bg-white p-4 rounded-lg shadow-sm flex flex-col sm:flex-row items-start sm:items-center justify-between border border-gray-200"
            >
              <div className="flex-grow">
                <p className="text-gray-500 text-sm">
                  {/* Ensure timestamp is a valid Firebase Timestamp object before calling toDate() */}
                  {transaction.timestamp && typeof transaction.timestamp.toDate === 'function'
                    ? new Date(transaction.timestamp.toDate()).toLocaleString('bn-BD', {
                        year: 'numeric', month: 'short', day: 'numeric',
                        hour: '2-digit', minute: '2-digit'
                      })
                    : 'Invalid Date'
                  }
                </p>
                <p className={`text-lg font-semibold ${transaction.type === 'got' ? 'text-green-600' : 'text-red-600'}`}>
                  {transaction.type === 'got' ? 'পেলেন' : 'দিলেন'}: {transaction.amount.toFixed(2)} টাকা
                </p>
                {transaction.description && (
                  <p className="text-gray-700 text-sm mt-1">বিবরণ: {transaction.description}</p>
                )}
              </div>
              <button
                onClick={() => handleDeleteTransaction(transaction.id, transaction.amount, transaction.type)}
                className="mt-3 sm:mt-0 px-3 py-1 bg-red-500 text-white text-sm rounded-md hover:bg-red-600 focus:outline-none focus:ring-2 focus:ring-red-500 focus:ring-opacity-50 transition duration-200 shadow-sm"
                aria-label="Delete transaction"
              >
                মুছুন
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
};

export default App;
